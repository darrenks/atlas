# -*- coding: ISO-8859-1 -*-
AST = Struct.new(:op,:args,:token,:is_flipped)

def parse_line(tokens)
  get_expr(balance_parens(tokens),false,nil)
end

def get_expr(tokens,apply,implicit_value)
  top = tokens.pop
  if top == nil || top.str == "("
    tokens << top if top != nil # not our job to consume (
    rhs = implicit_value
  elsif op=Ops1[top.str]
    arg = get_expr(tokens,apply|apply_check(tokens),implicit_value)
    rhs = AST.new(op,[arg],top)
  elsif top.str == ")"
    if tokens.empty? || tokens[-1].str == "("
      rhs = AST.new(EmptyOp,[],top)
    else
      v = new_paren_var
      rhs = AST.new(Ops2["set"], [get_expr(tokens,false,v),v], nil)
    end
    tokens.pop
  else
    rhs = make_op0(top)
  end
  return rhs if apply

  until tokens.empty? || tokens[-1].str == "("
    flipped = flip_check(tokens)
    from = tokens[-1]
    op=Ops2[from.str]
    if op && op.name == "set"
      if rhs.op.name == "var"
        rhs.token.ensure_name
      else
        if tokens[-1].str == "@"
          op=nil # allow it to mean apply implicit
        else
          raise ParseError.new("must set id's", tokens[-1])
        end
      end
    end
    tokens.pop if op
    lhs = get_expr(tokens,apply_check(tokens),implicit_value)
    rhs = AST.new(op||ImplicitOp,[lhs,rhs],from,flipped)
  end
  rhs
end

def apply_check(tokens)
  !tokens.empty? && tokens[-1].str == ApplyModifier && (tokens.pop; true)
end

def flip_check(tokens)
  !tokens.empty? && tokens[-1].str == FlipModifier && (tokens.pop; true)
end

$paren_vars = 0
def new_paren_var
  AST.new(Var,[],Token.new("paren_var#{$paren_vars+=1}"))
end

def make_op0(t)
  str = t.str
  if str =~ /^#{NumRx}$/
    AST.new(create_num(t),[],t)
  elsif str[0] == '"'
    AST.new(create_str(t),[],t)
  elsif str[0] == "'"
    AST.new(create_char(t),[],t)
  elsif (op=Ops0[str])
    AST.new(op,[],t)
  else
    AST.new(Var,[],t)
  end
end

def balance_parens(tokens)
  depth = left = 0
  tokens.each{|t|
    if t.str == '('
      depth += 1
    elsif t.str == ')'
      if depth == 0
        left += 1
      else
        depth -= 1
      end
    end
  }
  # +1 to also enclose in parens, so that top level implicit value never used
  [Token.new("(")]*(left+1) + tokens + [Token.new(")")]*(depth+1)
end
