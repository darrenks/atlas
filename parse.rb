# -*- coding: ISO-8859-1 -*-
AST = Struct.new(:op,:args,:token,:is_flipped)

def parse_line(tokens, last=nil)
  stacks = [[]]
  x=tokens.pop # eof # todo fixup
  tokens.unshift x
  next_atom_pops = false
  loop{ # main loop, expecing a value at start of each loop
    peek = tokens[-1].str
    if false && peek=="(" # ()
      stacks[-1] = AST.new(EmptyOp,[],tokens.pop)
    elsif peek==")"
      tokens.pop; stacks << []
    elsif Ops1.include? peek
      next_atom_pops = check_for_apply_modifier(tokens, next_atom_pops, stacks)
      stacks[-1] << make_op1(tokens.pop)
    else
      if peek == "(" || peek == :EOL # implicit value needed
        atom = stacks[-1].empty? ? AST.new(EmptyOp,[],tokens[-1]) : last
      else
        atom = make_op0(tokens.pop)
      end
      while tokens[-1].str == "("
        atom = pop_stack(stacks, atom)
        tokens.pop
        stacks = [[]] if stacks.empty? # more ( than )
      end
      if next_atom_pops == true
        next_atom_pops = false
        atom = pop_stack(stacks, atom)
      end

      # now expecing a binary op, since have value
      if tokens[-1].str == :EOL
        # could error if more than 1 because that is uselss
        atom=pop_stack(stacks, atom) until stacks.empty?
        return atom
      end
      is_flipped = tokens[-1].str == FlipModifier && (tokens.pop; true)
      next_atom_pops = check_for_apply_modifier(tokens, next_atom_pops, stacks)
      if Ops2.include? tokens[-1].str
        stacks[-1] << op = make_op2(tokens.pop,is_flipped)
        op.args = [atom]
      else # implicit op
        stacks[-1] << op = AST.new(ImplicitOp,[atom],tokens[-1],is_flipped)
      end
    end
  }
end

# todo handle invalid symbol lookup

def check_for_apply_modifier(tokens, next_atom_pops, stacks)
  if tokens[-2].str == ApplyModifier
    at=tokens.delete_at(-2)
    stacks << []
    raise ParseError.new("redundant apply modifer", at) if next_atom_pops
    true
  else
    next_atom_pops
  end
end

def pop_stack(stacks, atom)
  stacks.pop.reverse_each{|node|
    node.args.unshift atom
    atom = node
  }
  atom
end

def make_op0(t)
  str = t.str
  if str =~ /^#{NumRx}$/
    AST.new(create_num(str),[],t)
  elsif str[0] == '"'
    AST.new(create_str(str),[],t)
  elsif str[0] == "'"
    AST.new(create_char(str),[],t)
  elsif (op=Ops0[t.name])
    AST.new(op,[],t)
  else
    AST.new(Var,[],t)
  end
end

def make_op1(t)
  op = Ops1[t.name] || raise(ParseError.new("op not defined for unary operations",t))
  AST.new(op, [], t)
end

def make_op2(t,is_flipped) # todo error check not needed since already checked in parse?
  op = Ops2[t.name] || raise(ParseError.new("op not defined for binary operations",t))
  AST.new(op,[],t,is_flipped)
end

# todo rm
def is_op(t)
  AllOps.include?(t.name) && !Ops0.include?(t.name)
end

# this handles roman numerals in standard form
# a gimmick to provide a nice way of reprsenting some common numbers in few characters
RN = {"I"=>1,"V"=>5,"X"=>10,"L"=>50,"C"=>100,"D"=>500,"M"=>1000}
def to_roman_numeral(s)
  return nil if s.chars.any?{|c|!RN[c]} || !(s =~ /^M{0,3}(CM|CD|D?C?{3})(XC|XL|L?X?{3})(IX|IV|V?I?{3})$/)
  sum=0
  s.length.times{|i|
    v=RN[s[i]]
    if i < s.length-1 && RN[s[i+1]] > v
      sum-=v
    else
      sum+=v
    end
  }
  sum
end
