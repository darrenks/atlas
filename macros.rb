def apply_macros(ast)
  ast = replace_scans(ast)
  ast = replace_folds(ast)
  apply_flips(ast)
  ast
end

# todo auto replicate so that 1+S works

# a+(S+1) -> a[ (a>+(T+1)):T
def replace_scans(ast)
  raise ParseError.new"scan must be on rhs of an op",ast if ast.op.name == "scan"
  if ast.args.size == 2 && (s=lhs_has("scan", ast.args[1]))
    a = ast.args[0]
    v = new_var
    s.op = Var
    s.token = v.token
    AST.new(Ops2['let'], [
      AST.new(Ops2['append'], [
        AST.new(Ops1['head'], [a]),
        AST.new(ast.op, [
          AST.new(Ops1['tail'], [a]),
          ast.args[1]
        ], ast.token),
      ]),
      v
    ])
  else
    ast.args.map!{|arg| replace_scans(arg) }
    ast
  end
end

# a+(S+1) -> [(a[ (a>+(T+1)):T)
# todo do a foldr1 instead for better laziness
def replace_folds(ast)
  raise ParseError.new"fold must be on rhs of an op",ast if ast.op.name == "fold"
  if ast.args.size == 2 && (s=lhs_has("fold", ast.args[1]))
    a = ast.args[0]
    v = new_var
    s.op = Var
    s.token = v.token
    AST.new(Ops1['last'],[
    AST.new(Ops2['let'], [
      AST.new(Ops2['append'], [
        AST.new(Ops1['head'], [a]),
        AST.new(ast.op, [
          AST.new(Ops1['tail'], [a]),
          ast.args[1]
        ], ast.token),
      ]),
      v
    ])])
  else
    ast.args.map!{|arg| replace_folds(arg) }
    ast
  end
end

def apply_flips(ast)
  if ast.is_flipped
    raise ParseError.new "can only flip ops with 2 args", ast if ast.args.size != 2
    ast.args.reverse!
  end
  ast.args.each{|arg|apply_flips(arg)}
end

def lhs_has(needle,ast)
  return ast if ast.op.name == needle
  return nil if ast.args.size == 0
  lhs_has(needle,ast.args[0])
end

$new_vars = 0
def new_var
  AST.new(Var,[],Token.new("_T#{$new_vars+=1}"))
end