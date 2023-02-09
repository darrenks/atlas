def infer(root)
  all = all_nodes(root)
  all.each{|node|node.used_by = []}
  all.each{|node|node.orig_args.each{|arg| arg.used_by << node} }

  dfs_infer(root)

  errors = []
  dfs(root) { |node|
    if node.last_error
      errors << node.last_error if node.orig_args.all?{|arg| arg.type != nil }
      node.type = nil
    end
  }
  errors[0...-1].each{|error| STDERR.puts error.message }
  raise errors[-1] if !errors.empty?
end

def dfs_infer(node)
  return if node.type
  node.type = Nil # for cycle, Nil instead of Unknown since cycle can't be scalar

  node.orig_args.each{|arg| dfs_infer(arg) }

  update_type(node)
end

def update_type(node)
  return if node.orig_args.any?{|arg|!arg.type}
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
      check_base_elem_constraints(fn_type.specs, node.orig_args.map(&:type))
    rescue AtlasTypeError
      false
    end
  }

  if fn_types.size == 0
    node.last_error = AtlasTypeError.new("op is not definied for arg types: " + node.orig_args.map{|arg|arg.type.inspect}*',', node)
    return Nil
  elsif fn_types.size == 2
    node.last_error = AtlasTypeError.new("op is ambiguous for arg types: " + node.orig_args.map{|arg|arg.type.inspect}*',', node)
    return Nil
  else
    fn_type = fn_types[0]
  end

  arg_types = node.orig_args.map(&:type)
#STDERR.puts arg_types.inspect
#   p node.token.str if node.token

  pre_zip_level = node.from ? node.from.pre_zip_level || 0 : 0
  arg_types.map!{|t| t-pre_zip_level }

  min_implicit_zip_level = implicit_zip_level(node.op, arg_types, fn_type.specs)
  zip_level = node.explicit_zip_level + min_implicit_zip_level + node.op.min_zip_level + pre_zip_level
#STDERR.puts "zip_level = %d" % zip_level

  arg_types.map!{|t| t-(zip_level-pre_zip_level) }

  vars = solve_type_vars(arg_types, fn_type.specs)

  replicated_args = replicate_and_promote_as_needed(fn_type, node, vars, arg_types, zip_level, pre_zip_level)
#       replicated_args.each{|arg| t=arg.type;raise AtlasTypeError.new("cannot zip into nil",nil) if t.is_nil && t.dim <= node.zip_level }
  t = spec_to_type(fn_type.ret, vars) + zip_level

  node.replicated_args = replicated_args
  node.zip_level = zip_level
  t
end

def replicate_and_promote_as_needed(fn_type, node, vars, arg_types,zip_level,pre_zip_level)
  all_repped = true
  rank_deficits = rank_deficits(arg_types, fn_type.specs, vars, zip_level)

  promote_levels = promote_levels(node,rank_deficits,zip_level,vars)

  replicated_args = node.orig_args.map.with_index{|arg,i|
    arg = implicit_promoten(arg, promote_levels[i],[zip_level,arg.type.dim].min)
    rep_level = rank_deficits[i] - promote_levels[i]

    all_repped &&= rep_level > 0
#     raise AtlasTypeError.new "can't replicate nil",nil if arg == Nil && rep_level > 0
    implicit_repn(arg, rep_level, pre_zip_level)
  }
  if node.orig_args.size > 0 && all_repped
    node.last_error ||= AtlasTypeError.new "zip level too high", node
  end
  replicated_args
end

def implicit_repn(arg, rep_level, pre_zip_level)
  # should be solved so that check is not needed
#   raise AtlasTypeError.new "would need negative rep level", nil if rep_level < 0
  rep_level.times { arg = implicit_rep(arg,pre_zip_level) }
  return arg
end

def implicit_rep(arg,pre_zip_level)
  n=IR.new(RepOp,[arg],nil,arg.type+1,pre_zip_level)
  n.replicated_args = n.orig_args
  n
end


def implicit_promoten(arg, promote_level,zip_level)
  # do nothing since this actually valid
  #raise "would need negative promote level" if promote_level < 0
  promote_level.times { arg = implicit_promote(arg,zip_level) }
  return arg
end

def implicit_promote(arg,zip_level)
  n=IR.new(PromoteOp,[arg],nil,arg.type+1,zip_level)
  n.replicated_args = n.orig_args
  n
end

def check_base_elem_constraints(specs, arg_types)
  solve_type_vars(arg_types, specs) # consistency check
  arg_types.zip(specs).all?{|type,spec|
    spec.check_base_elem(type)
  }
end

###############################
# Solve for the minimum possible zip level that satisfies all constraints
# constraints:
#   0 <= rep levels <= z
#   type vars satisfiable
def implicit_zip_level(op, arg_types, specs)
  vars = {}
  rep_vars = {}
  min_z = 0
  arg_types.zip(specs,0..) { |arg,spec,i|
    case spec
    when VarTypeSpec
      (vars[spec.var_name]||=[]) << (arg - spec.extra_dims)
      if op.promote < SECOND_PROMOTE || op.promote == SECOND_PROMOTE && i==1
        (rep_vars[spec.var_name]||=[]) << (arg - spec.extra_dims)
      end
    when ExactTypeSpec
      this_z = arg.dim - spec.req_dim
      min_z = [min_z, this_z].max
    else
      error
    end
  }
  #if op.promote < SECOND_PROMOTE
    vars.each{|k,uses|
      min_use = [uses.map{|t| t.max_pos_dim }.min, 0].max
      max_use = [(rep_vars[k]||[]).map{|t| t.dim }.max || 0, 0].max
      min_z = [min_z, max_use-min_use].max
    }
  #end
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
    if arg.is_nil && arg.dim > zip_level
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

def promote_levels(node,rank_deficits,zip_level,vars)
  promote_levels = node.orig_args.zip(rank_deficits,(0..)).map{|arg,deficit,i|
    if node.orig_args.size == 1 && node.op.promote >= ALLOW_PROMOTE && arg.type.dim >= zip_level
      deficit
    elsif node.op.promote >= PREFER_PROMOTE || node.op.promote == SECOND_PROMOTE && i==1
      [zip_level <= arg.type.dim ? deficit : arg.type.dim, deficit - zip_level].max
    elsif node.op.promote >= ALLOW_PROMOTE
      [deficit - zip_level, 0].max
    else
      if deficit > zip_level
        node.last_error ||= AtlasTypeError.new "rank is too low for argument %d" % [i+1], node
      end
      0
    end
  }
  promote_levels
end
