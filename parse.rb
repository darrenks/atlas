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
      var_name = nodes[i].token.str
      nodes[i] = context[var_name] || raise(ParseError.new("unset identifier %p" % var_name, nodes[i].token))
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
  raise ParseError.new "unexpected end of line",t if t.str == "\n"
  raise ParseError.new "unexpected )",t if t.str == ")" # later will be empty parens which means empty list
  op = get_op(t)
  lhs = if t.str == "("
    get_expr(tokens,context,depth+1)
  elsif op.name == "var"
    Var.new(t)
  elsif op.narg == 0
    AST.new(op, [], t)
  elsif true # uop
    return AST.new(op, [get_expr(tokens,context,depth)], t)
  else
    impossible
  end

  lhs_t = t
  if tokens.empty? || tokens[0].str =="\n"
    raise ParseError.new "unexpected end of expression, expecting ')'",t if depth > 0
    return lhs
  end
  t = tokens.shift
  if t.str == ")"
    raise ParseError.new "unmatched )", t if depth <= 0
    return lhs
  end

  op = get_op(t)
  if t.str == "="
    warn("duplicate assignment to var: " + lhs_t.str, t) if context[lhs_t.str]
    context[lhs_t.str] = get_expr(tokens,context,depth)
  elsif op.narg == 0
    raise ParseError.new("2 adjacent atoms is illegal for now (will mean cons later)", t)
  elsif op.narg == 1 || op.narg == 2 # binop
    AST.new(op, [lhs, get_expr(tokens,context,depth)], t)
  elsif op.narg == 3
    AST.new(op, [lhs, get_expr(tokens,context,depth+1), get_expr(tokens,context,depth)], t)
  else
    impossible2
  end
end

def get_op(token)
  str = token.str
  if str[0] =~ /[0-9]/
    create_int(str)
  elsif str[0] == '"'
    create_str(str)
  elsif str[0] == "'"
    create_char(str)
#   elsif is_special_zip(str)
#     Ops[str].dup
  elsif Ops.include? str[/!*(.*)/m,1]
    Ops[str[/!*(.*)/m,1]]
  elsif str != $/
    Op.new("var")
  else
    raise
  end
end
