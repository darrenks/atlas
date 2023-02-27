AST = Struct.new(:op,:args,:token)

def parse_line(tokens, stack)
  ast = get_expr(tokens,:EOL)
  ast = handle_data_form(ast)
  handle_push_pops(ast, stack)
end

DelimiterPriority = {:EOL => 0, ')' => 1}
LBrackets = {"(" => ")"}

DataForm = Struct.new(:type, :value)

def get_expr(tokens,delimiter)
  last = lastop = implicit_var = nil
  was_first = true
  loop {
    atom,t = get_atom(tokens)
    if atom
      # spaces indicate it was to actually be a unary op
      if lastop && last && Ops1[lastop.name] && (lastop.space_after && !lastop.space_before && !is_op(t) && !lastop.is_alpha || !Ops2[lastop.name])
        last = make_op1(lastop, last)
        lastop = nil
      end

      if lastop #binary op
        last = implicit_var = new_var if !last
        last = make_op2(lastop, last, atom)
      elsif !last #first atom
        last = atom
      else # implict cons
        if DataForm === last && DataForm === atom && was_first && (dtype=last.type.data_can_be(atom.type))
          last = DataForm.new(dtype+1, [last.value,atom.value])
          was_first = false
        elsif DataForm === last && DataForm === atom && !was_first && (dtype=last.type.data_can_be(atom.type+1))
          last = DataForm.new(dtype, last.value << atom.value)
        else
          last = AST.new(Ops2["‿"],[last,atom],t)
        end
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
        raise ParseError.new("op applied to nothing",t) if implicit_var && !last
        if implicit_var
          last = AST.new(Ops2['let'], [last, implicit_var], t)
        elsif !last
          last = DataForm.new(Nil,[])
        elsif DataForm === last && was_first && delimiter != :EOL
          last = DataForm.new(last.type+1, [last.value])
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
    DataForm.new(Int, str.to_i)
  elsif str[0] == '"'
    DataForm.new(Str, parse_str(str[1...-1]).chars.map(&:ord))
  elsif str[0] == "'"
    AST.new(create_char(str),[],t)
  elsif (op=Ops0[t.name])
    AST.new(op,[],t)
  elsif is_op(t)
    if !t.is_alpha && t.space_before && !t.space_after
      atom, t2 = get_prefix_atom(tokens)
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
    AST.new(Var,[],t)
  end,t]
end

def get_prefix_atom(tokens)
  if is_op(tokens[0])
    t = tokens.shift
    atom, t2 = get_prefix_atom(tokens)
    if atom
      [make_op1(t, atom), t]
    else
      [nil, t2]
    end
  else
    get_atom(tokens)
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

def handle_data_form(ast)
  if DataForm === ast
    if ast.type == Int
      impl = ast.value
    else
      impl = rec_to_lazy_list(ast.value)
    end
    op = create_op(
      sym: "data",
      name: "data",
      type: ast.type,
      impl: impl
    )
    ast = AST.new(op, [])
  else
    ast.args.map!{|arg|
      handle_data_form(arg)
    }
  end
  ast
end
