# old indentation idea:
# higher indentation = higher parse depth
# must go to orig parse depth for unindent

# todo raw string indent idea
# "asdf""1234" = ["asdf","1234"]

Var =  Struct.new(:token)

def replace_vars(node,context)
  if Var === node
    var_name = node.token.str
    raise(ParseError.new("unset identifier %p" % var_name, node.token)) unless context.include? var_name
    context[var_name].from_var = var_name
    return replace_vars(context[var_name], context)
  end
  return node if node.replaced
  node.replaced = true
  orig = node.args.dup
  begin
    node.args.map!{|arg|replace_vars(arg,context)}
  rescue ParseError => pe
    node.args.replace(orig)
    node.replaced = false
    raise pe
  end
  node
end

def parse_line(tokens,context)
  get_expr(tokens,context,:EOL,DelimiterPriority[:EOL],nil)
end

DelimiterPriority = {:EOL => 0, 'else' => 0, ')' => 1, '}' => 2}
LBrackets = {"(" => ")", "{" => "}"}

def get_expr(tokens,context,delimiter,priority,last)
  lastop = nil
  loop {
    atom,t = get_atom(tokens,context)
    if atom
      # spaces indicate it was to actually be a unary op
      if lastop && last && lastop.space_after && !lastop.space_before && !is_op(t) && is_sym(lastop.str)
        last = make_op1(lastop, last)
        lastop = nil
      end

      if lastop
        implicit_value_check(lastop, last)
        if (op=Ops3[lastop.name])
          arg2 = get_expr(tokens,context,lastop.name=="then"?"else":")",DelimiterPriority['else'],atom)
          arg3,t2 = get_atom(tokens,context)
          check_for_delimiter(t2, delimiter, priority, tokens, nil){|ret| return AST.new(op,[last,arg2,ret])}
          implicit_value_check(t2, arg3)
          last = AST.new(op,[last,arg2,arg3],lastop)
        elsif lastop.str == ":" # to do, don't do this in parsing...
          assertVar(atom.token)
          warn("duplicate assignment to var: " + atom.token.str, t) if context[t.str]
          context[atom.token.str] = last
        else# actual regular binary op
          last = make_op2(lastop, last, atom)
        end
      elsif !last #first atom
        last = atom
      else # implict cons
        last = AST.new(Ops2[" "],[last,atom],t)
      end
      lastop = nil
    else # not an atom
      if lastop
        implicit_value_check(lastop, last)
        last = make_op1(lastop, last)
      end

      check_for_delimiter(t, delimiter, priority, tokens, last){|ret| return ret}
      lastop = t
    end
  }
end

def implicit_value_check(lastop, last)
  raise ParseError.new "value missing and implicit value isn't implemented yet",lastop if !last
end

def check_for_delimiter(t, delimiter, priority, tokens, last)
  if DelimiterPriority[t.str]
    if t.str != delimiter
      if DelimiterPriority[t.str] >= priority
        raise ParseError.new "unexpected #{t.str}, expecting #{delimiter}", t
      else # e.g. token is eof, expecting )
        # return without consuming token
        tokens.unshift t
      end
    end
    yield last || AST.new(NilOp,[],t)
  end
end

# return atom or nil
def get_atom(tokens,context)
  t = tokens.shift
  str = t.str
  [if LBrackets.include? t.str
    rb = LBrackets[t.str]
    get_expr(tokens,context,rb,DelimiterPriority[rb],nil)
  elsif str[0] =~ /[0-9]/
    AST.new(create_int(str),[],t)
  elsif str[0] == '"'
    AST.new(create_str(str),[],t)
  elsif str[0] == "'"
    AST.new(create_char(str),[],t)
  elsif str =~ ArgRegex
    i = if str=="::"
      context.keys.grep(Integer).max
    else
      str[1..-1].to_i
    end

    context[i] || raise(ParseError.new("line #{i} not set yet", t))
#   elsif is_special_zip(str)
#     Ops[str].dup
  elsif (op=Ops0[t.name])
    AST.new(op,[],t)
  elsif is_op(t)
    if is_sym(str) && t.space_before && !t.space_after
      atom, t2 = get_prefix_atom(tokens,context)
      if atom
        return [make_op1(t, atom), t]
      else
        tokens.unshift t2
        return [nil, t]
      end
    else
      nil
    end
  elsif DelimiterPriority[str]
    nil
  else
    Var.new(t)
  end,t]
end

def get_prefix_atom(tokens,context)
  if is_op(tokens[0])
    t = tokens.shift
    atom, t2 = get_prefix_atom(tokens,context)
    if atom
      [make_op1(t, atom), t]
    else
      [nil, t2]
    end
  else
    get_atom(tokens,context)
  end
end

def make_op1(t,arg)
  op = Ops1[t.name] || raise(ParseError.new("op not defined for unary operations",t))
  AST.new(op, [arg], t)
end

def make_op2(t,arg1,arg2)
  op = Ops2[t.name] || raise(ParseError.new("op not defined for binary operations",t))
  AST.new(op,[arg1,arg2],t)
end

def is_op(t)
  AllOps.include?(t.str[/!*(.*)/m,1]) && !Ops0.include?(t.str[/!*(.*)/m,1]) || t.str==":"
end

def is_sym(s)
  !(s =~ /^\!*#{VarRegex}$/)
end
