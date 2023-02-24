def apply_macros(ast, stack)
  save_orig(ast)
  ast=handle_push_pops(ast, stack)
  apply_flips(ast)
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

# todo remove this and .orig
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

