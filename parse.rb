AST = Struct.new(:op,:args,:token)

def parse_line(tokens, stack)
  ast = get_expr(tokens,:EOL)
  handle_push_pops(ast, stack)
end

DelimiterPriority = {:EOL => 0, ')' => 1}
LBrackets = {"(" => ")"}

def get_expr(tokens,delimiter)
  last = lastop = implicit_var = nil
  loop {
    atom,t = get_atom(tokens)
    if atom
      if lastop #binary op
        last = implicit_var = new_var if !last
        last = make_op2(lastop, last, atom)
      elsif !last #first atom
        last = atom
      else # implict op
        last = AST.new(Ops2[" "],[last,atom],t)
      end
      lastop = nil
    else # not an atom
      if lastop
        last = implicit_var = new_var if !last
        last = make_op1(lastop, last)
      end

      if DelimiterPriority[t.str]
        if t.str != delimiter
          if DelimiterPriority[t.str] >= DelimiterPriority[delimiter]
            raise ParseError.new "unexpected #{t.str}, expecting #{delimiter}", t
          else # e.g. token is eof, expecting )
            # return without consuming token
            tokens.unshift t
          end
        end
        last ||= AST.new(EmptyOp,[],t)
        if implicit_var
          last = AST.new(Ops2['let'], [last, implicit_var], t)
        end
        return last
      end

      lastop = t
    end
  }
end

# return atom or nil
def get_atom(tokens)
  t = tokens.shift
  str = t.str
  [if LBrackets.include? t.str
    rb = LBrackets[t.str]
    get_expr(tokens,rb)
  elsif str[0] =~ /[0-9]/
    AST.new(create_int(str),[],t)
  elsif str[0] == '"'
    AST.new(create_str(str),[],t)
  elsif str[0] == "'"
    AST.new(create_char(str),[],t)
  elsif (op=Ops0[t.name])
    AST.new(op,[],t)
  elsif is_op(t)
    nil
  elsif DelimiterPriority[str]
    nil
  else
    AST.new(Var,[],t)
  end,t]
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
  AllOps.include?(t.name) && !Ops0.include?(t.name)
end

def handle_push_pops(ast, stack)
  ast.args[0] = handle_push_pops(ast.args[0], stack) if ast.args.size > 0
  if ast.op.name == "push"
    ast = AST.new(Ops2["let"], [ast.args[0], new_var], ast.token)
    stack.push ast
  elsif ast.op.name == "pop"
    raise ParseError.new("pop on empty stack", ast) if stack.empty?
    ast = stack.pop
  end
  ast.args[1] = handle_push_pops(ast.args[1], stack) if ast.args.size > 1

  ast
end

$new_vars = 0
def new_var
  AST.new(Var,[],Token.new("_T#{$new_vars+=1}"))
end
