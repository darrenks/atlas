def infer(root)
  all = all_nodes(root)
  q=[]
  # these are topologically sorted from post traversal dfs which gives a favorable order to start inference from
  all.each{|node|
    node.used_by = [];
    if node.type_with_vec_level == nil
      node.type_with_vec_level = UnknownV0
      node.in_q = true
      q << node
    end
  }
  all.each{|node|node.args.each{|arg| arg.used_by << node} }

  q.each{|node| # this uses q as a queue
    node.in_q = false
    prev_type = node.type_with_vec_level
    calc_type(node)
    if node.type_with_vec_level != prev_type && !node.last_error
      node.type_updates = (node.type_updates || 0) + 1
      if node.type_updates > 100
        if node.type.dim < 20 && node.vec_level < 20
          raise "congratulations you have found a program that does not find a fixed point for its type, please report this discovery - I am not sure if it possible and would like to know"
        end
        raise AtlasTypeError.new "cannot construct the infinite type" ,node
      end

      node.used_by.each{|dep|
        if !dep.in_q
          dep.in_q = true
          q << dep
        end
      }
    end
  }

  errors = []
  dfs(root) { |node|
    if node.last_error
      errors << node.last_error if node.args.all?{|arg| arg.type_with_vec_level != nil }
      node.type_with_vec_level = nil
    end
  }
  errors[0...-1].each{|error| STDERR.puts error.message }
  raise errors[-1] if !errors.empty?
  root
end

# finds best matching type for a spec (multiple would be possible if overloading by rank)
def match_type(types, arg_types)
  fn_types = types.select{|fn_type|
    check_base_elem_constraints(fn_type.specs, arg_types)
  }
  return nil if fn_types.empty?
  if fn_types.size > 1
    fn_types.sort_by!{|fn_type|
      fn_type.specs.zip(arg_types).map{|spec,type|
        (spec.type.dim-type.dim).abs # only handles specs of exact type, but that is all there should be if overloading this way.
      }
    }
  end
  return fn_types[0]
end

def calc_type(node)
  node.last_error = nil
  fn_type = match_type(node.op.type, node.args.map(&:type))
  return node.type_error "op is not defined for arg types: " + node.args.map{|arg|arg.type_with_vec_level.inspect}*',' if !fn_type
  node.type_with_vec_level = possible_types(node,fn_type)
end

def possible_types(node, fn_type)
  arg_types = node.args.map(&:type)
  vec_levels = node.args.map(&:vec_level)
  unvec_at_end = false

  vec_levels = vec_levels.zip(fn_type.specs,0..).map{|vec_level,spec,i|
    if spec.vec_of
      if vec_level == 0
        return node.type_error "vec level is 0, cannot lower" if node.op.name == "unvec"
        unvec_at_end = true if node.op.name == 'consDefault' && arg_types[0].dim > 0
        arg_types[i]-=1 # auto vec
        0
      else
        vec_level - 1
      end
    else
      vec_level
    end
  }

  nargs = arg_types.size
  vars = solve_type_vars(arg_types, fn_type.specs)
  deficits = rank_deficits(arg_types, fn_type.specs, vars)
  rep_levels = [0]*nargs
  promote_levels = [0]*nargs

  # auto promote both if equal
  if node.op.name == "build" && deficits[1]==0 && deficits[0]==0
    # if any are unknown, only promote smaller or rank 1s
    all_known = !arg_types.any?(&:is_unknown)
    if all_known || arg_types[0].dim <= arg_types[1].dim
      promote_levels[0] += 1
    end
    if all_known || arg_types[1].dim <= arg_types[0].dim
      promote_levels[1] += 1
    end
  end

  # auto unvectorize
  nargs.times{|i|
    unvec = node.args[i].op.name == "vectorize" ? 0 : [[vec_levels[i], deficits[i]].min, 0].max
    unvec -= 1 if node.op.name == "build" && unvec > 0
    vec_levels[i] -= unvec
    deficits[i] -= unvec
  }

  # auto promote
  nargs.times{|i|
    promote = [0, deficits[i]].max
    if node.op.name == "build" && promote == 0 && deficits[1-i]<0
      promote_levels[i] += 1
      deficits[1-i] += 1
    elsif promote > 0 && node.op.no_promote
      return node.type_error "rank too low for arg #{i+1}"
    else
      promote_levels[i] += promote
      deficits[i] -= promote
    end
  }

  # auto vectorize
  nargs.times{|i|
    vec_levels[i] -= deficits[i]
  }

  zip_level = vec_levels.max || 0
  nargs.times{|i|
    rep_levels[i] = zip_level - vec_levels[i]
    return node.type_error "rank too high for arg #{i+1}" if rep_levels[i] > zip_level
    arg_types[i] += promote_levels[i]
  }

  node.zip_level = zip_level
  node.rep_levels = rep_levels
  node.promote_levels = promote_levels

  vars = solve_type_vars(arg_types, fn_type.specs)
  t = spec_to_type(fn_type.ret, vars)
  t.vec_level += zip_level
  if unvec_at_end
    t.vec_level -= 1
    t.type.dim += 1
  end
  t
end

def solve_type_vars(arg_types, specs)
  vars = {} # todo separate hash for ret and uses?

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
    max_min_dim = uses.reject(&:is_unknown).map(&:dim).min
    base_elems = uses.map(&:base_elem).uniq
    base_elem = if base_elems == [Unknown.base_elem]
      max_min_dim = uses.map(&:dim).max
      Unknown.base_elem
    else
      base_elems -= [Unknown.base_elem]
      base_elems[0]
    end

    vars[name] = Type.new([max_min_dim,0].max, base_elem)
  }
  vars
end

def rank_deficits(arg_types, specs, vars)
  arg_types.zip(specs).map{|arg,spec|
    spec_dim = case spec
      when VarTypeSpec
        vars[spec.var_name].max_pos_dim + spec.extra_dims
      when ExactTypeSpec
        spec.type.dim
      else
        error
      end
    if arg.is_unknown
      [spec_dim - arg.dim, 0].min
    else
      spec_dim - arg.dim
    end
  }
end

def check_base_elem_constraints(specs, arg_types)
  uses={}
  arg_types.zip(specs).all?{|type,spec|
    spec.check_base_elem(uses,type)
  }
end
