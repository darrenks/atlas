def apply_macros(ast)
  save_orig(ast)
  ast = replace_scans(ast)
  ast = replace_folds(ast)
  apply_flips(ast)
  ast = apply_maps(ast)
  check_any_map_vars_left_over(ast)
  ast
end

def save_orig(ast)
  dup_args = ast.args.map{|arg| save_orig(arg) }
  dup = ast.dup
  dup.args = dup_args
  ast.orig = dup
  dup
end

# todo auto replicate so that 1+S works

# todo if the op was zipped
# todo nested

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
