require_relative "./ops.rb"
require_relative "./ast.rb"

# higher indentation = higher parse depth
# must go to orig parse depth for unindent
# only 1 non assignment top level

class AST
  attr_accessor :replaced_memo
end

def parse(tokens)
  context={}
  prog=parse_top_level(tokens,context)
  op=Ops["O"].dup
  op.token=Token.new("O",0,0)
  AST.new(op,[replace_vars(prog,context)])
end

def replace_vars(node,context)
  if Var === node
    str = node.token.str
    raise ParseError.new("unset identifier %p" % str, node.token) unless context.include? str
    return replace_vars(context[str],context)
  end
  return node if node.replaced_memo
  node.replaced_memo = true
  node.args.map!{|arg|replace_vars(arg,context)}
  node
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
      ans = rec(tokens, context)
    else
      last = rec(tokens, context)
    end
    return ans||last if tokens.empty?
    raise ParseError.new "expecting newline or eof",tokens[0].token if tokens[0].str != "\n"
  end
end

Var=Struct.new(:token)

# todo for golfing, allow no =, and no spaces between identifiers

def rec(tokens, context)
  raise ParseError.new "unexpected EOF",nil if tokens.empty?
  t = tokens.shift
  ret = AST.new # important to create this for modifying its reference
  if !tokens.empty? && tokens[0].str == "="
    # todo check for overwrite existing var / built in
    context[t.str] = ret
    tokens.shift # the =
    t = tokens.shift
  end
  if t.impl == nil && t.poly_impl == nil
    return Var.new(t.token)
  end
  ret.op = t
  ret.args = t.narg.times.map{rec(tokens, context)}
  ret
end