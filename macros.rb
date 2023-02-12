def apply_macros(ast, stack)
  save_orig(ast)
  ast=handle_push_pops(ast, stack)
  apply_flips(ast)
  ast = apply_maps(ast)
  check_any_map_vars_left_over(ast)
  ast
end

def handle_push_pops(ast, stack)
  ast.args[0] = handle_push_pops(ast.args[0], stack) if ast.args.size > 0
  if ast.op.name == "push"
    ast = AST.new(Ops2["let"], [ast.args[0], new_var], ast.token)
    stack.push ast
  elsif ast.op.name == "pop"
    raise ParseError.new("pop on empty stack", ast) if stack.empty?
    ast = stack.pop
  end
  ast.args[1] = handle_push_pops(ast.args[1], stack) if ast.args.size > 1

  ast
end

$new_vars = 0
def new_var
  AST.new(Var,[],Token.new("_T#{$new_vars+=1}"))
end

def save_orig(ast)
  dup_args = ast.args.map{|arg| save_orig(arg) }
  dup = ast.dup
  dup.args = dup_args
  ast.orig = dup
  dup
end

def apply_flips(ast)
  if ast.is_flipped
    raise ParseError.new "can only flip ops with 2 args", ast if ast.args.size != 2
    ast.args.reverse!
  end
  ast.args.each{|arg|apply_flips(arg)}
end

def apply_maps(ast)
  ast.args.map!{|arg| apply_maps(arg) }
  if ast.op.name == "map"
    new_ast,used=do_map(ast.args[0])
    raise ParseError.new "you did a map without ever using its map var", ast if !used
    return new_ast
  end
  return ast
end

def check_any_map_vars_left_over(ast)
  ast.args.each{|arg|check_any_map_vars_left_over(arg)}
  raise ParseError.new "unused map var", ast if ast.op.name == "mapVar"
end

def do_map(ast)
  if ast.op.name == "mapVar"
    ast = ast.args[0]
    if ast.op.name != "mapVar"
      ast,_ = do_map(ast)
      return [ast,true]
    else
      return rdo_map(ast)
    end
  end
  used_map_var = []
  new_args = []
  ast.args.each{|arg|
    new_arg,used=do_map(arg)
    used_map_var << used
    new_args << new_arg
  }
  ast.args = new_args
  any = used_map_var.any?
  if any
    ast.args = ast.args.zip(used_map_var).map{|arg,used|
      if !used
        AST.new(RepOp, [arg])
      else
        arg
      end
    }
    ast.pre_zip_level = (ast.pre_zip_level || 0) + 1
  end
  return [ast,any]
end

# do_map, but inside of a larger mapVar, so don't count those
def rdo_map(ast)
  if ast.op.name == "mapVar"
    arg,used = rdo_map(ast.args[0])
    ast.args[0] = arg
    [ast, used]
  else
    do_map(ast)
  end
end
