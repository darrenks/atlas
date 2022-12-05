require_relative "./error.rb"

def infer(root)
  all = all_nodes(root)
  all.each{|node|node.used_by = []}
  all.each{|node|node.args.each{|arg| arg.used_by << node} }

  dfs_infer(root)

  all.each{|node|
    node.args = node.replicated_args
    raise AtlasTypeError.new "no matches, last err=" + node.last_error[0].message, nil if node.last_error != nil
  }
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

  if prev_type != :pending && node.type != prev_type
    node.used_by.each{|dep|
      #raise "shouldnt happen" if dep.type == :pending
      update_type(dep) if dep.type
    }
  end
end

def possible_types(node)
  ret = nil
  errors = []
  any_no_errors = false
  node.op.type.each{|fn_type|
   node.last_error = nil
   begin
    arg_types = node.args.map(&:type)
#STDERR.puts arg_types.inspect
                           # todo not used yet  #
    min_implicit_zip_level,max_implicit_zip_level = implicit_zip_level(arg_types, fn_type.specs)
    zip_level = node.op.explicit_zip_level + min_implicit_zip_level
#STDERR.puts "zip_level = %d" % zip_level

    arg_types.map!{|t| t-zip_level }

    vars = solve_type_vars(arg_types, fn_type.specs)

    replicated_args = replicate_as_needed(fn_type, node, vars, arg_types, zip_level)
#       replicated_args.each{|arg| t=arg.type;raise AtlasTypeError.new("cannot zip into nil",nil) if t.is_nil && t.dim <= node.zip_level }
    check_constraints(node, fn_type.specs, replicated_args.map{|arg|arg.type - zip_level})
    t = spec_to_type(fn_type.ret, vars) + zip_level
#       raise AtlasTypeError.new "can't replicate this case",nil if node.type && node.type != :PENDING && node.type != t # e.g. from cons hardcoded
#       raise AtlasTypeError.new "expecting type %p, found %p" % [node.expected_type, t], nil if node.expected_type && !t.can_be(node.expected_type)  }

    node.replicated_args = replicated_args
    node.zip_level = zip_level

    if !ret
      ret = t
    else
      ret |= t
    end
   rescue AtlasTypeError => e
    node.last_error = e
   end
   if node.last_error
    errors << node.last_error
   else
    any_no_errors = true
   end
  }
  #raise node.last_error if ret == nil
  node.last_error = any_no_errors ? nil : errors
  return Nil if ret == nil
  ret
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
  AST.new(RepOp,[arg],arg.type+1,0)
end
