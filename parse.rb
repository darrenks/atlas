require_relative "./ops.rb"
require_relative "./ast.rb"

# old indentation idea:
# higher indentation = higher parse depth
# must go to orig parse depth for unindent

Var=Struct.new(:token)

def replace_vars(node,context)
  if Var === node
    var_name = node.token.str
    raise(ParseError.new("unset identifier %p" % var_name, node.token)) unless context.include? var_name
    return replace_vars(context[var_name], context)
  end
  return node if node.replaced
  node.replaced = true
  node.args.map!{|arg|replace_vars(arg,context)}
  node
end

def parse_line(tokens,context)
  get_expr(tokens,context,:EOF,nil)
end

def get_expr(tokens,context,delimiter,last)
  lastop = nil
  loop {
    atom,t = get_atom(tokens,context)
    if atom # bin op

      # spaces indicate it was to actually be a unary op
      if lastop && last && $prev && !$prev.space_after && lastop.space_after
        last = AST.new(get_op1(t),[last],t)
        lastop = nil
      end

      if lastop
        if lastop.str == "="
          warn("duplicate assignment to var: " + t.str, t) if context[t.str]
          context[t.str] = last
        else
          raise ParseError.new "value missing and implicit value isn't implemented yet",lastop if !last
          if (op=Ops3[lastop.name])
            arg2 = get_expr(tokens,context,lastop.name=="then"?"else":")",atom)
            arg3,_ = get_atom(tokens,context)
            last = AST.new(op,[last,arg2,arg3],lastop)
          else # actual regular binary op
            last = AST.new(Ops2[lastop.name],[last,atom],lastop)
          end
        end
      elsif !last #first atom
        last = atom
      else # implict cons
        implicit_t = t.dup
        implicit_t.str = "implicit_promote_and_append"
        last = AST.new(get_op2(implicit_t),[last,atom],implicit_t)
      end
      lastop = nil
    else
      if lastop
        raise ParseError.new "value missing and implicit value isn't implemented yet",lastop if !last
        last = AST.new(get_op1(lastop),[last],lastop)
      end
      if Delimiters[t.str]
        raise ParseError.new "unexpected #{t.str}, expecting #{delimiter}", t if t.str != delimiter
        return last || AST.new(NilOp,[],t)
      end
      lastop = t
    end
  }
end

Delimiters = {}; [')','else',:EOF].each{|k|Delimiters[k]=true}

$curr=nil
$prev=nil
# return atom or nil
def get_atom(tokens,context)
  $prev = $curr
  $curr = t = tokens.shift
  str = t.str
  [if str == "("
    get_expr(tokens,context,')',nil)
  elsif str[0] =~ /[0-9]/
    AST.new(create_int(str),[],t)
  elsif str[0] == '"'
    AST.new(create_str(str),[],t)
  elsif str[0] == "'"
    AST.new(create_char(str),[],t)
#   elsif is_special_zip(str)
#     Ops[str].dup
  elsif (op=Ops0[t.name])
    AST.new(op,[],t)
  elsif Delimiters[str] || AllOps.include?(str[/!*(.*)/m,1]) || str=="="
    nil
  else
    Var.new(t)
  end,t]
end

def get_op1(t)
  Ops1[t.name] || raise(ParseError.new("op not defined for unary operations",t))
end

def get_op2(t)
  Ops2[t.name] || raise(ParseError.new("op not defined for binary operations",t))
end
