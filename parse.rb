AST = Struct.new(:op,:args,:token)

def parse_line(tokens, stack)
  ast = get_expr(tokens,:EOL)
  handle_push_pops(ast, stack)
end

DelimiterPriority = {:EOL => 0, ')' => 1}
LBrackets = {"(" => ")"}

def get_expr(tokens,delimiter)
  lastop = implicit_var = nil
  nodes = []
  loop {
    atom,t = get_atom(tokens)
    if atom
      if lastop #binary op
        nodes << implicit_var = new_var if nodes.empty?
        if lastop.str == ApplyModifier && atom.op.name == "var"
          # would register as a modifier to implicit op, override this
          nodes << AST.new(Ops2[ApplyModifier], [], lastop) << atom
        else
          nodes << make_op2(lastop) << atom
        end
      elsif nodes.empty? #first atom
        nodes << atom
      else # implict op
        nodes << AST.new(Ops2[" "],[],t) << atom
      end
      lastop = nil
    else # not an atom
      if lastop
        nodes << implicit_var = new_var if nodes.empty?
        if lastop.str =~ /(.*)(#{FlipRx})$/
          if !$1.empty? # lexer falsely thought it was an op modifier, split it into 2 tokens
            z=lastop.dup
            z.str = $1
            nodes << make_op1(z)
            lastop.char_no += $1.size
            lastop.str = $2
          end
          nodes << AST.new(Ops1[FlipModifier], [], lastop)
        else
          nodes << make_op1(lastop)
        end
      end

      if DelimiterPriority[t.str]
        nodes << AST.new(EmptyOp,[],t) if nodes.empty?
        if implicit_var
          nodes << AST.new(Ops2['let'], [], t) << implicit_var
          implicit_var = nil
        end
        if t.str != delimiter
          if DelimiterPriority[t.str] >= DelimiterPriority[delimiter]
            # e.g. encountered ) but no ( to match, do nothing except process implicit_var
            next
          else # e.g. token is eof, expecting )
            # return without consuming token
            tokens.unshift t
          end
        end

        break
      end
      lastop = t
    end
  }

  ops=[]
  atoms=[]
  until nodes.empty?
    o = nodes.pop

    if o.token.str[/^#{ApplyRx}/] && o.op.name != "let"
      x = nodes[-1]
      while nodes[-1].args.size<nodes[-1].op.narg
        nodes.pop.args << nodes[-1]
      end
      nodes.pop
      o.args << x
      (o.op.narg-1).times{ o.args << atoms.pop }
    end

    if o.args.size==o.op.narg
      atoms << o
    else
      ops << o
    end
  end

  v=atoms.pop
  until ops.empty?
    n=ops[-1].op.narg
    ops[-1].args << v
    v = ops.pop
    (n-1).times{ v.args << atoms.pop }
  end
  v
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

def make_op1(t)
  op = Ops1[t.name] || raise(ParseError.new("op not defined for unary operations",t))
  AST.new(op, [], t)
end

def make_op2(t)
  op = Ops2[t.name] || raise(ParseError.new("op not defined for binary operations",t))
  AST.new(op,[],t)
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
