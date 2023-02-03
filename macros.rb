# todo auto replicate so that 1+S works

# a+(S+1) -> a[ (a>+(T+1)):T
def replace_scans(ast)
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
        ]),
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
        ]),
      ]),
      v
    ])])
  else
    ast.args.map!{|arg| replace_scans(arg) }
    ast
  end
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