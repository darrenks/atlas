require_relative "./error.rb"

def infer(root)
  all = all_nodes(root)
  all.each{|node|node.used_by = []}
  all.each{|node|node.args.each{|arg| arg.used_by << node} }

  dfs_infer(root)

  errors = []
  dfs(root) { |node|
    if node.last_error
      errors << node.last_error if node.args.all?{|arg| arg.type != nil }
      node.type = nil
    end
  }
  errors[0...-1].each{|error| STDERR.puts error.message }
  raise errors[-1] if !errors.empty?

  all.each{|node| node.args = node.replicated_args }
end

def dfs_infer(node)
  return if node.type
  node.type = Nil # for cycle, Nil instead of Unknown since cycle can't be scalar

  node.args.each{|arg| dfs_infer(arg) }

  update_type(node)
end

def update_type(node)
  return if node.args.any?{|arg|!arg.type}
  prev_type = node.type
  node.type = possible_types(node)

  if node.type != prev_type
    node.used_by.each{|dep| update_type(dep) }
  end
end

def possible_types(node)
  node.last_error = nil
  fn_types = node.op.type.select{|fn_type|
    begin
      check_base_elem_constraints(fn_type.specs, node.args.map(&:type))
    rescue AtlasTypeError
      false
    end
  }

  if fn_types.size == 0
    node.last_error = AtlasTypeError.new("op is not definied for arg types: " + node.args.map{|arg|arg.type.inspect}*',', node)
    return Nil
  elsif fn_types.size == 2
    node.last_error = AtlasTypeError.new("op is ambiguous for arg types: " + node.args.map{|arg|arg.type.inspect}*',', node)
    return Nil
  else
    fn_type = fn_types[0]
  end

  arg_types = node.args.map(&:type)
#STDERR.puts arg_types.inspect
  min_implicit_zip_level = implicit_zip_level(arg_types, fn_type.specs)
  zip_level = node.explicit_zip_level + min_implicit_zip_level + node.op.min_zip_level
#STDERR.puts "zip_level = %d" % zip_level

  arg_types.map!{|t| t-zip_level }

  vars = solve_type_vars(arg_types, fn_type.specs)

  replicated_args = replicate_as_needed(fn_type, node, vars, arg_types, zip_level)
#       replicated_args.each{|arg| t=arg.type;raise AtlasTypeError.new("cannot zip into nil",nil) if t.is_nil && t.dim <= node.zip_level }
  t = spec_to_type(fn_type.ret, vars) + zip_level
#       raise AtlasTypeError.new "can't replicate this case",nil if node.type && node.type != :PENDING && node.type != t # e.g. from cons hardcoded
#       raise AtlasTypeError.new "expecting type %p, found %p" % [node.expected_type, t], nil if node.expected_type && !t.can_be(node.expected_type)  }

  node.replicated_args = replicated_args
  node.zip_level = zip_level
  t
end

def replicate_as_needed(fn_type, node, vars, arg_types,zip_level)
  all_repped = true
  rank_deficits = rank_deficits(arg_types, fn_type.specs, vars, zip_level)
  replicated_args = node.args.map.with_index{|arg,i|
    rep_level = rank_deficits[i]
    node.last_error ||= AtlasTypeError.new "rank is too low for argument %d" % [i+1], node if rep_level > zip_level
    all_repped &&= rep_level > 0

#     raise AtlasTypeError.new "can't replicate nil",nil if arg == Nil && rep_level > 0
    implicit_repn(arg, rep_level)
  }
  node.last_error ||= AtlasTypeError.new "zip level too high", node if node.args.size > 0 && all_repped
  replicated_args
end

def implicit_repn(arg, rep_level)
  # should be solved so that check is not needed
#   raise AtlasTypeError.new "would need negative rep level", nil if rep_level < 0
  rep_level.times { arg = implicit_rep(arg) }
  return arg
end

def implicit_rep(arg)
  AST.new(RepOp,[arg],nil,arg.type+1,0)
end

def check_base_elem_constraints(specs, arg_types)
  solve_type_vars(arg_types, specs) # consistency check
  specs.zip(arg_types).all?{|spec,type|
    spec.check_base_elem(type)
  }
end

###############################
# Solve for the minimum possible zip level that satisfies all constraints
# constraints:
#   0 <= rep levels <= z
#   type vars satisfiable
def implicit_zip_level(arg_types, specs)
  vars = {}
  min_z = 0
  arg_types.zip(specs) { |arg,spec|
    case spec
    when VarTypeSpec
      (vars[spec.var_name]||=[]) << (arg - spec.extra_dims)
    when ExactTypeSpec
      this_z = arg.is_nil ?
        arg.dim - spec.req_dim : # nil has only min req rank
        (arg.dim - spec.req_dim).abs
      min_z = [min_z, this_z].max
    else
      error
    end
  }
  vars.each{|_,uses|
    min_use = uses.map{|t| t.max_pos_dim }.min
    max_use = [uses.map{|t| t.dim }.max, 0].max
    min_z = [min_z, max_use-min_use].max
  }
  return min_z
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

  vars.each{|name,uses|
    max_min_dim = uses.map(&:dim).max
    base_elems = uses.map(&:base_elem).uniq
    base_elem = if base_elems == [:nil]
      :nil
    else
      base_elems -= [:nil]
      raise AtlasTypeError.new("inconsistant base elem %p" % uses, nil) if base_elems.size != 1
      base_elems[0]
    end

    vars[name] = Type.new([max_min_dim,0].max, base_elem)
  }
  vars
end

def rank_deficits(arg_types, specs, vars, zip_level)
  arg_types.zip(specs).map{|arg,spec|
    if arg.is_nil #&& arg.dim > zip_level
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
