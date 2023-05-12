def infer(root)
  all = all_nodes(root)
  q=[]
  # these are topologically sorted from post traversal dfs which gives a favorable order to start inference from
  all.each{|node|
    node.used_by = [];
    if node.type == nil
      node.type = Unknown
      node.in_q = true
      q << node
    end
  }
  all.each{|node|node.args.each{|arg| arg.used_by << node} }

  q.each{|node| # this uses q as a queue
    node.in_q = false
    prev_type = node.type
    calc_type(node)
    if node.type != prev_type && !node.last_error
      node.type_updates = (node.type_updates || 0) + 1
      if node.type_updates > 100
        if node.type.rank < 20
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
      errors << node.last_error if node.args.all?{|arg| arg.type != nil }
      node.type = nil
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
  return node.type_error "op is #{fn_types.size==0?'not definied':'ambiguous'} for arg types: " + node.args.map{|arg|arg.type.inspect}*',' if fn_types.size != 1

  node.type = possible_types(node,fn_types[0])
end

def possible_types(node, fn_type)
  arg_types = node.args.map(&:type)
  vars,zip_level = solve_type_vars(arg_types, fn_type.specs, node)
  arg_types = arg_types.map{|type| type - zip_level }
  deficits = rank_deficits(arg_types, fn_type.specs, vars)
  return node.type_error "cannot unvectorize op" if zip_level < 0 ||  deficits.any?{|d| d < 0}

  return node.type_error "rank too low, cannot promote" if node.op.no_promote && deficits.any?{|d| d > zip_level }

  node.zip_level = zip_level
  node.deficits = deficits

  return spec_to_type(fn_type.ret, vars) + zip_level
end

def solve_type_vars(arg_types, specs, node)
  var_use = {}
  zip_level = 0

  arg_types.zip(specs) { |arg,spec|
    case spec
    when VarTypeSpec
      (var_use[spec.var_name]||=[]) << arg - spec.extra_dims
    when ExactTypeSpec
      zip_level = [zip_level,arg.rank-spec.type.rank].max
    else
      error
    end
  }

  max_excess = var_use.map{|k,u|[k,u.map(&:rank).max]}.to_h
  zip_level = [zip_level,max_excess.values.min||0].max
  zip_level -= node.vec_mod

  var_ans = {}
  var_use.each{|name,uses|
    base_elems = uses.map(&:base).uniq
    base_elem = if base_elems == [Unknown.base]
      Unknown.base
    else
      base_elems -= [Unknown.base]
      base_elems[0]
    end

    var_ans[name] = Type.new([max_excess[name] - zip_level,0].max, base_elem)
  }

  [var_ans,zip_level]
end

def rank_deficits(arg_types, specs, vars)
  arg_types.zip(specs).map{|arg,spec|
    spec_dim = case spec
      when VarTypeSpec
        vars[spec.var_name].max_pos_dim + spec.extra_dims
      when ExactTypeSpec
        spec.type.rank
      else
        error
      end
    if arg.is_unknown
      [spec_dim - arg.rank, 0].min
    else
      spec_dim - arg.rank
    end
  }
end

def check_base_elem_constraints(specs, arg_types)
  uses={}
  arg_types.zip(specs).all?{|type,spec|
    spec.check_base_elem(uses,type)
  }
end
