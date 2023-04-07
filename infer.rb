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

def calc_type(node)
  node.last_error = nil
  fn_types = node.op.type.select{|fn_type|
    check_base_elem_constraints(fn_type.specs, node.args.map(&:type))
  }

  return node.type_error "op is #{fn_types.size==0?'not definied':'ambiguous'} for arg types: " + node.args.map{|arg|arg.type_with_vec_level.inspect}*',' if fn_types.size != 1

  node.type_with_vec_level = possible_types(node,fn_types[0])
end

def possible_types(node, fn_type)
  arg_types = node.args.map(&:type)
  vec_levels = node.args.map(&:vec_level)

  vec_levels = vec_levels.zip(fn_type.specs,0..).map{|vec_level,spec,i|
    if spec.vec_of
      if vec_level == 0
        return node.type_error "vec level is 0, cannot lower" if node.op.name == "unvec" || arg_types[i].dim == 0
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
  t = spec_to_type(fn_type.ret, vars)
  rep_levels = [0]*nargs
  promote_levels = [0]*nargs

  if node.op.name == "snoc" && deficits[1]<0 #&& arg_types[0] == arg_types[1]
    deficits[1] += 1
    promote_levels[0] += 1
    t = TypeWithVecLevel.new(t.type+1,t.vec_level)
  end

  nargs.times{|i|
    if deficits[i]>0
      if deficits[i] > vec_levels[i] || node.args[i].op.name == "vectorize"
        if node.op.no_promote
          return node.type_error "rank too low for arg #{i+1}"
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
  nargs.times{|i|
    rep_levels[i] += zip_level - vec_levels[i] - rep_levels[i]
    return node.type_error "rank too high for arg #{i+1}" if rep_levels[i] > zip_level
  }
  node.zip_level = zip_level
  node.rep_levels = rep_levels
  node.promote_levels = promote_levels

  t.vec_level += zip_level
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
