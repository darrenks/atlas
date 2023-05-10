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

def snoc_type(node)
  a,b = node.args.map(&:type)
  if a.rank > b.rank
    t=a.dup
  else
    t=b+1
  end
  node.zip_level = 0
  node.rep_levels = [0,0]
  node.promote_levels = [t.rank-a.rank,t.rank-b.rank-1]
  t
end

def possible_types(node, fn_type)
  return snoc_type(node) if node.op.name == "snoc"
  arg_types = node.args.map(&:type)
  vars = solve_type_vars(arg_types, fn_type.specs)
#   deficits = rank_deficits(arg_types, fn_type.specs, vars)

  arg_zip_levels = arg_types.zip(fn_type.specs).map{|arg,spec|arg.rank - spec.extra_rank}
  promote_levels = arg_zip_levels.map{|z|
    if z < 0
      return node.type_error "rank too low, cannot promote" if node.op.no_promote
      -z
    else
      0
    end
  }
  arg_zip_levels.map!{|z|[z,0].max}

  zip_level = arg_zip_levels.max || 0
  rep_levels = arg_zip_levels.map{|z|zip_level - z}
  zip_level -= node.from.token.vec_mod
  return node.type_error "rank too low, cannot promote" if zip_level < 0
  vars.each{|k,v|vars[k]+=node.from.token.vec_mod}
  t = spec_to_type(fn_type.ret, vars).dup

#     return node.type_error "rank too high for arg #{i+1}" if rep_levels[i] > zip_level
  node.zip_level = zip_level
  node.rep_levels = rep_levels
  node.promote_levels = promote_levels
  t.rank += zip_level
  t
end

def solve_type_vars(arg_types, specs)
  var_uses = {}

  arg_types.zip(specs) { |arg,spec|
    case spec
    when VarTypeSpec
      (var_uses[spec.var_name]||=[]) << arg - spec.extra_dims
    when ExactTypeSpec
    else
      error
    end
  }

  vars = {}
  var_uses.each{|name,uses|
    base_elems = uses.map(&:base).uniq
    base_elem = if base_elems == [Unknown.base]
      Unknown.base
    else
      base_elems -= [Unknown.base]
      base_elems[0]
    end

    vars[name] = Type.new(0, base_elem)
  }
  vars
end

def rank_deficits(arg_types, specs, vars)
  # todo remove?
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
