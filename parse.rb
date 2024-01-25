# -*- coding: ISO-8859-1 -*-
AST = Struct.new(:op,:args,:token,:is_flipped)

def parse_line(tokens, implicit_value=nil)
  stacks = [[]]
  tokens.unshift Token.new(:BOL)
  next_atom_pops = false
  loop{ # main loop, expecing a value at start of each loop
    peek = tokens[-1].str
    if peek==")"
      tokens.pop; stacks << []
    elsif (op=Ops1[peek])
      next_atom_pops = check_for_apply_modifier(tokens, next_atom_pops, stacks)
      stacks[-1] << AST.new(op, [], tokens.pop)
    else
      if peek == "(" || peek == :BOL # implicit value needed
        atom = stacks[-1].empty? ? AST.new(EmptyOp,[],tokens[-1]) : implicit_value
      else
        atom = make_op0(tokens.pop) # todo would make a var out of "add"
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
      if tokens[-1].str == :BOL
        # we could error instead if more than 1 because that is uselss
        atom=pop_stack(stacks, atom) until stacks.empty?
        return atom
      end
      is_flipped = tokens[-1].str == FlipModifier && (tokens.pop; true)
      next_atom_pops = check_for_apply_modifier(tokens, next_atom_pops, stacks)
      op=Ops2[tokens[-1].str]
      stacks[-1] << AST.new(op||ImplicitOp ,[atom],tokens[-1],is_flipped)
      tokens.pop if op
    end
  }
end

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
  elsif (op=Ops0[str])
    AST.new(op,[],t)
  else
    AST.new(Var,[],t)
  end
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
