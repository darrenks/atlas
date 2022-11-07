require_relative "./error.rb"

def infer(root)
  to_check = [root]
  to_check.each{|node| inferh(node, to_check) }
end

def inferh(node,to_check)
  raise AtlasTypeError.new "circular program not in right hand side of cons found, this would always result in an infinite loop", node if :PENDING == node.type
  return if node.type
  node.type = :PENDING

  if node.op.str[-1] == ":" # or can only unzipped be circular? transpose should need it = it is needed for the zip faith test
    inferh(node.args[0], to_check)
    raise AtlasTypeError.new "zip level too high",nil if node.op.explicit_zip_level > node.args[0].type.dim
    node.zip_level = node.op.explicit_zip_level
    node.type = node.args[0].type + 1
    node.args[1].expected_type = node.type
    to_check << node.args[1]
    return
  end
  if node.op.str[-1] == "|" # or can only unzipped be circular? transpose should need it = it is needed for the zip faith test
    inferh(node.args[1], to_check)
    raise AtlasTypeError.new "zip level too high",nil if node.op.explicit_zip_level > node.args[1].type.dim
    node.zip_level = node.op.explicit_zip_level
    node.type = node.args[1].type + 1
    node.args[0].expected_type = node.type
    to_check << node.args[0]
    return
  end
  if node.op.str[-1] == "@" # or can only unzipped be circular? transpose should need it = it is needed for the zip faith test
    inferh(node.args[0], to_check)
    raise AtlasTypeError.new "zip level too high",nil if node.op.explicit_zip_level > node.args[0].type.dim-1
    node.zip_level = node.op.explicit_zip_level
    node.type = node.args[0].type
    node.args[1].expected_type = node.type
    to_check << node.args[1]
    return
  end
  node.args.each{|arg| inferh(arg, to_check) }

  # todo +1 for K maybe others later

  last_err = nil
  node.op.type.each{|fn_type|
    arg_types = node.args.map(&:type)
    begin
      node.zip_level = node.op.explicit_zip_level + z=min_zip_level(arg_types, fn_type.specs)
      arg_types.map!{|t| t-node.zip_level }
      vars = solve_type_vars(arg_types, fn_type.specs)

      replicated_args = replicate_as_needed(fn_type, node, vars, arg_types)
      replicated_args.each{|arg| t=arg.type;raise AtlasTypeError.new("cannot zip into nil",nil) if t.is_nil && t.dim <= node.zip_level }
      check_constraints(fn_type.specs, replicated_args.map{|arg|arg.type - node.zip_level})
      t = spec_to_type(fn_type.ret, vars) + node.zip_level
#       raise AtlasTypeError.new "can't replicate this case",nil if node.type && node.type != :PENDING && node.type != t # e.g. from cons hardcoded
      raise AtlasTypeError.new "expecting type %p, found %p" % [node.expected_type, t], nil if node.expected_type && !t.can_be(node.expected_type)
      node.type = t
    rescue AtlasTypeError => e
      last_err = e
#       p replicated_args.map(&:type)
#       puts e.message
      next
    end
    node.args = replicated_args
    return
  }
  raise AtlasTypeError.new "no matches, last err=" + last_err.message, nil
end

def replicate_as_needed(fn_type, node, vars, arg_types)
  all_repped = true
  rank_deficits = rank_deficits(arg_types, fn_type.specs, vars, node.zip_level)
  replicated_args = node.args.map.with_index{|arg,i|
    rep_level = rank_deficits[i]
    # should be solved so that impossible
#        raise AtlasTypeError.new "rank is too low for argument %d" % [i+1], node if rep_level > node.zip_level
    all_repped &&= rep_level > 0

#     raise AtlasTypeError.new "can't replicate nil",nil if arg == Nil && rep_level > 0
    implicit_repn(arg, rep_level)
  }
  raise AtlasTypeError.new "zip level too high", node if node.args.size > 0 && all_repped
  replicated_args
end

def implicit_repn(arg, rep_level)
  # not sure if this checked needed
  raise AtlasTypeError.new "would need negative rep level", nil if rep_level < 0
  rep_level.times { arg = implicit_rep(arg) }
  return arg
end

def implicit_rep(arg)
  AST.new(RepOp,[arg],arg.type+1,0)
end
