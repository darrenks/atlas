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
    expr = get_expr(line_tokens,context,:EOF)
    if is_stmt
      last_stmt = [expr]
    else
      exprs << expr
    end
  }
  exprs.empty? ? last_stmt : exprs
end

def get_expr(tokens,context,delimiter)
  raise ParseError.new "unexpected EOF",nil if tokens.empty?
  t = tokens.shift
  raise ParseError.new "unexpected end of line",t if t.str == "\n"
  raise ParseError.new "unexpected )",t if t.str == ")" # later will be empty parens which means empty list
  raise ParseError.new "unexpected then",t if t.str == "then"
  raise ParseError.new "unexpected else",t if t.str == "else"
  op = get_op(t,Ops1,"unary")
  lhs = if t.str == "("
    get_expr(tokens,context,')')
  elsif op.name == "var"
    Var.new(t)
  elsif op.narg == 0
    AST.new(op, [], t)
  elsif op.narg == 1
    return AST.new(op, [get_expr(tokens,context,delimiter)], t)
  elsif op.name == "if"
    c=get_expr(tokens,context,"then")
    a=get_expr(tokens,context,"else")
    b=get_expr(tokens,context,delimiter)
    return AST.new(op, [c,a,b], t)
  else # op.narg > 1
    raise ParseError.new "found non unary op with no left hand side", t
  end

  lhs_t = t
  if tokens.empty? || tokens[0].str =="\n"
    raise ParseError.new "unexpected end of expression, expecting '#{delimiter}'",t if delimiter != :EOF
    return lhs
  end
  t = tokens.shift
  if [')','then','else'].include? t.str
    raise ParseError.new "unmatched #{t.str}", t if delimiter == :EOF
    raise ParseError.new "expecting #{delimiter}" if t.str != delimiter
    return lhs
  end

  if t.str == "="
    warn("duplicate assignment to var: " + lhs_t.str, t) if context[lhs_t.str]
    context[lhs_t.str] = get_expr(tokens,context,delimiter)
  elsif t.str == "(" ||
        t.str =~ /^\!*if$/ ||
        (lhs_t.space_after && !t.space_after) ||
        (op = get_op(t,Ops2,"non-unary")).narg == 0
    tokens.unshift(t)
    rhs = get_expr(tokens,context,delimiter)
    implicit_t = t.dup
    implicit_t.str = "implicit" # replace, could have been !if, etc. which would zip
    AST.new(Ops2[' '], [lhs, rhs], implicit_t)
  elsif op.narg == 2 # binop
    AST.new(op, [lhs, get_expr(tokens,context,delimiter)], t)
  elsif op.sym == "?"
    c=get_expr(tokens,context,")")
    a=get_expr(tokens,context,delimiter)
    AST.new(op, [c,a,lhs], t)
  else
    impossible2
  end
end

def get_op(token,ops,ops_name)
  str = token.str
  if str[0] =~ /[0-9]/
    create_int(str)
  elsif str[0] == '"'
    create_str(str)
  elsif str[0] == "'"
    create_char(str)
#   elsif is_special_zip(str)
#     Ops[str].dup
  elsif ops.include? str[/!*(.*)/m,1]
    ops[str[/!*(.*)/m,1]]
  elsif AllOps.include? str[/!*(.*)/m,1]
    raise ParseError.new("op not defined for %s operations" % ops_name,token)
  elsif str != $/
    Op.new("var")
  else
    raise
  end
end
