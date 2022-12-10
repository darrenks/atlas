require_relative "./ops.rb"
require_relative "./ast.rb"

# old indentation idea:
# higher indentation = higher parse depth
# must go to orig parse depth for unindent

def parse_infix(tokens)
  context={}
  prog=parse_top_level(tokens,context)
  replace_vars(prog,context)
end


Var=Struct.new(:token)

def replace_vars(node,context)
  if Var === node
    context[node.token.str] || raise(ParseError.new("unset identifier %p" % node.token.str, node.token))
  else
    node.args.map!{|arg|replace_vars(arg,context)}
    node
  end
end

def parse_top_level(tokens,context)
  #tokens.filter{|t|t.op.str != " "}
  ans=nil
  last=nil
  while true
    while tokens[0].str == "\n"
      tokens.shift
      return ans||last if tokens.empty?
    end
    if tokens.size < 2 || tokens[1].str != "="
      raise ParseError.new "there can only be 1 non assignment line", tokens[0].token if ans!=nil
      ans = get_expr(tokens,context,0)
    else
      last = get_expr(tokens,context,0)
    end
    return ans||last if tokens.empty?
    raise ParseError.new "expecting newline or eof",tokens[0].token if tokens[0].str != "\n"
  end
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