require_relative "./ops.rb"
require_relative "./ast.rb"

# old indentation idea:
# higher indentation = higher parse depth
# must go to orig parse depth for unindent

def parse_infix(tokens)
  context={}
  roots = parse_top_level(tokens,context)
  replace_vars(roots, context)
end

Var=Struct.new(:token)

def replace_vars(nodes,context)
  nodes.size.times{|i|
    while Var === nodes[i]
      nodes[i] = context[nodes[i].token.str] || raise(ParseError.new("unset identifier %p" % nodes[i].token.str, nodes[i].token))
    end
    next if nodes[i].replaced
    nodes[i].replaced = true
    replace_vars(nodes[i].args,context)
  }
  nodes
end

# return a list of ASTs to print (only the exprs or last statement if none)
def parse_top_level(tokens,context)
  last_stmt = []
  lines = tokens.chunk_while{|token|token.str != "\n" }
  exprs = []
  lines.each{|line_tokens|
    next if line_tokens.empty? || line_tokens[0].str == "\n"
    is_stmt = line_tokens.size > 1 && line_tokens[1].str == "="
    expr = get_expr(line_tokens,context,0)
    if is_stmt
      last_stmt = [expr]
    else
      exprs << expr
    end
  }
  exprs.empty? ? last_stmt : exprs
end

def get_expr(tokens,context,depth)
  raise ParseError.new "unexpected EOF",nil if tokens.empty?
  t = tokens.shift
  raise ParseError.new "unexpected )",nil if t.str == ")" # later will be empty parens which means empty list
#   raise ParseError.new "unexpected newline",nil if t.str =="\n"
  lhs = if t.str == "("
    get_expr(tokens,context,depth+1)
  elsif t.name == "var"
    Var.new(t.token)
  elsif t.narg == 0
    AST.new(t, [])
  elsif true # uop
    return AST.new(t, [get_expr(tokens,context,depth)])
  else
    impossible
  end

  lhs_t = t
  if tokens.empty? || tokens[0].str =="\n"
    raise "unexpected eof" if depth > 0
    return lhs
  end
  t = tokens.shift
  if t.str == ")"
    raise "unexpected ) or eof" if depth <= 0
    return lhs
  end

  if t.str == "="
    # todo error if duplicate assign or op assign
    context[lhs_t.str] = get_expr(tokens,context,depth)
  elsif t.narg == 0
    errorz # for now cons
  elsif t.narg == 1 || t.narg == 2 # binop
    AST.new(t, [lhs, get_expr(tokens,context,depth)])
  elsif t.narg == 3
    AST.new(t, [lhs, get_expr(tokens,context,depth+1), get_expr(tokens,context,depth)])
  else
    impossible2
  end
end