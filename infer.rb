def infer(root)
  all = all_nodes(root)
  all.each{|node|node.used_by = []}
  all.each{|node|node.args.each{|arg| arg.used_by << node} }

  dfs_infer(root)

  errors = []
  dfs(root) { |node|
    if node.last_error
      errors << node.last_error if node.args.all?{|arg| arg.type_with_vec_level != nil }
      node.type_with_vec_level = nil
    end
  }
  errors[0...-1].each{|error| STDERR.puts error.message }
  raise errors[-1] if !errors.empty?
end

def dfs_infer(node)
  return if node.type_with_vec_level
  node.type_with_vec_level = NilV0 # for cycle, Nil instead of Unknown since cycle can't be scalar

  node.args.each{|arg| dfs_infer(arg) }

  update_type(node)
end

def update_type(node)
  return if node.args.any?{|arg|!arg.type_with_vec_level}
  prev_type = node.type_with_vec_level

  node.last_error = nil
  fn_type = get_fn_type(node)
  node.type_with_vec_level = fn_type ? possible_types(node,fn_type) : NilV0

  if node.type_with_vec_level != prev_type
    node.type_updates = (node.type_updates || 0) + 1
    raise AtlasTypeError.new "cannot construct the infinite type",node if node.type_updates > 100
    node.used_by.each{|dep| update_type(dep) }
  end
end

def get_fn_type(node)
  fn_types = node.op.type.select{|fn_type|
    begin
      check_base_elem_constraints(fn_type.specs, node.args.map(&:type))
    rescue AtlasTypeError
      false
    end
  }

  if fn_types.size == 0
    node.last_error = AtlasTypeError.new("op is not definied for arg types: " + node.args.map{|arg|arg.type_with_vec_level.inspect}*',', node)
    nil
  elsif fn_types.size == 2
    node.last_error = AtlasTypeError.new("op is ambiguous for arg types: " + node.args.map{|arg|arg.type_with_vec_level.inspect}*',', node)
    nil
  else
    fn_types[0]
  end
end

def possible_types(node, fn_type)
  if !node.op.no_zip
    arg_types = node.args.map(&:type)
    vec_levels = node.args.map(&:vec_level)
  else
    arg_types = node.args.map{|a|a.type+a.vec_level}
    vec_levels = node.args.map{|a|0}
  end

  vec_levels = vec_levels.zip(fn_type.specs).map{|vec_level,spec|
    if spec.vec_of
      node.last_error ||= AtlasTypeError.new "vec level is 0, cannot lower",node if vec_level == 0
      vec_level - 1
    else
      vec_level
    end
  }

  nargs = arg_types.size
  vars = solve_type_vars(arg_types, fn_type.specs)
  deficits = rank_deficits(arg_types, fn_type.specs, vars)
  t = spec_to_type(fn_type.ret, vars)
  rep_levels = [0]*nargs
  promote_levels = [0]*nargs

  if node.op.name == "snoc" && deficits[1]<0
    deficits[1] += 1
    promote_levels[0] += 1
    t = TypeWithVecLevel.new(t.type+1,t.vec_level)
  end

  nargs.times{|i|
    if deficits[i]>0
      if deficits[i] > vec_levels[i] || node.args[i].op.name == "vectorize"
        if node.op.no_promote
          node.last_error ||= AtlasTypeError.new "rank too low for arg #{i+1}",node
        elsif node.args[i].op.name == "vectorize"
          promote_levels[i] += deficits[i]
          deficits[i] = 0
        else
          promote_levels[i] += deficits[i] - vec_levels[i]
          deficits[i] = vec_levels[i]
        end
      end
    elsif deficits[i] < 0
      rep_levels[i] -= deficits[i]
    end
    vec_levels[i] -= deficits[i]
  }
  zip_level = vec_levels.max || 0
  zip_level = 0 if node.op.no_zip
  nargs.times{|i|
    rep_levels[i] += zip_level - vec_levels[i] - rep_levels[i]
    node.last_error ||= AtlasTypeError.new "rank too high for arg #{i+1}",node if rep_levels[i] > zip_level
  }
  node.zip_level = zip_level
  node.rep_levels = rep_levels
  node.promote_levels = promote_levels

  t.vec_level += zip_level
  t
end

def solve_type_vars(arg_types, specs)
  vars = {}

  arg_types.zip(specs) { |arg,spec|
    case spec
    when VarTypeSpec
      (vars[spec.var_name]||=[]) << arg - spec.extra_dims
    when ExactTypeSpec
    else
      error
    end
  }

  mixed_typeable = vars[Achar] && vars[Aint]
  vars.dup.each{|name,uses|
    if name == Achar
      (vars[A]||=[]).concat uses
      raise AtlasTypeError.new("base elem must be char",nil) if name == Achar && uses.any?{|u|!u.is_char}
      vars.delete(name)
    elsif name == Aint
      (vars[A]||=[]).concat uses
      vars.delete(name)
      raise AtlasTypeError.new("base elem must be int",nil) if name == Aint && uses.any?{|u|u.is_char}
    end
  }

  vars.each{|name,uses|
    max_min_dim = uses.map(&:dim).min
    base_elems = uses.map(&:base_elem).uniq
    base_elem = if base_elems == [:nil]
      :nil
    else
      base_elems -= [:nil]
      raise AtlasTypeError.new("inconsistant base elem %p" % uses, nil) if base_elems.size != 1 && !mixed_typeable
      base_elems[0]
    end

    vars[name] = Type.new([max_min_dim,0].max, base_elem)
  }

  if mixed_typeable
    vars[Achar] = Type.new(vars[A].dim,Char.base_elem)
    vars[Aint] = Type.new(vars[A].dim,Int.base_elem)
  end
  vars
end

def rank_deficits(arg_types, specs, vars)
  arg_types.zip(specs).map{|arg,spec|
    if arg.is_nil && arg.dim > 0
      0
    else
      spec_dim = case spec
        when VarTypeSpec
          vars[spec.var_name].dim + spec.extra_dims
        when ExactTypeSpec
          spec.req_dim
        else
          error
        end
      spec_dim - arg.dim
    end
  }
end

def check_base_elem_constraints(specs, arg_types)
  solve_type_vars(arg_types, specs) # consistency check
  arg_types.zip(specs).all?{|type,spec|
    spec.check_base_elem(type)
  }
end
