# -*- coding: ISO-8859-1 -*-
$ir_node_count = 0
class IR < Struct.new(
    :op,                  # these set during construction
    :from,                # ast
    :raw_args,            # args with vars not expanded
    :args,                # args with vars expanded
    :type_with_vec_level, # this and rest calculted in infer
    :zip_level,
    :promise,
    :id, # set during init
    :in_q,
    :used_by,
    :rep_levels,
    :promote_levels,
    :last_error,
    :type_updates, # for detecting inf type
    )
  def initialize(*args)
    super(*args)
    self.id = $ir_node_count += 1
  end
  def type
    type_with_vec_level.type
  end
  def vec_level
    type_with_vec_level.vec_level
  end
  def type_error(msg)
    self.last_error ||= AtlasTypeError.new msg,self
    UnknownV0
  end
end

# todo check this logic
# does do more work, as internal paren vars are created even if they can't be reached
def update(new,old,context,parents)
  if old.op.name == "var"
    name = old.from.token.str
    return false if parents[name]
    parents[name] = true
    ans = new != context[old.from.token.str] || update(new,new,context,parents)
    parents[name] = false
    ans
  elsif old.op.name == "ans"
    false
  else
    changed = !new.args || new.args.zip(old.raw_args).any?{|new_arg,old_arg|
      update(new_arg,old_arg,context,parents)
    }
    old.args = old.promise = old.type_with_vec_level = nil if changed
    changed
  end
end

def to_ir(ast,context,last)
  context.each{|k,v| update(v,v,context,{}) }
  ir=create_ir_and_set_vars(ast,context,last)
  lookup_vars(ir,context)
end

def create_ir_and_set_vars(node,context,last)
  if node.op.name == "set"
    raise "only identifiers may be set" if node.args[1].op.name != "var"
    set(node.args[1].token, node.args[0], context,last)
  elsif node.op.name == "save"
    ir = create_ir_and_set_vars(node.args[0],context,last)
    vars = [*'a'..'z']-context.keys
    raise(StaticError.new("out of save vars", node)) if vars.empty?
    set(Token.new(vars[0]),ir,context,last)
  elsif node.op.name == "ans"
    raise StaticError.new("there is no last ans to refer to",node) if !last
    last
  else
    args=node.args.map{|arg|create_ir_and_set_vars(arg,context,last)}
    args.reverse! if node.is_flipped
    IR.new(node.op,node,args)
  end
end

def lookup_vars(node,context)
  return node if node.args
  if node.op.name == "var"
    name = node.from.token.str
    val = get(context, name, node.from)
    val = IR.new(UnknownOp,node.from,[]) if val == node # todo this isn't actually useful is it?
    lookup_vars(val,context)
  else
    node.args = :processing
    node.args = node.raw_args.map{|arg| lookup_vars(arg,context) }
    node
  end
end

def set(t,node,context,last)
  name = t.str
  $warn_on_unset_vars ||= name.size > 1 && !name[/_/]
  if Commands[name] || AllOps[name]
    warn("overwriting %p even though it is an op" % name, t)
    Ops0.delete(name)
    Ops1.delete(name)
    Ops2.delete(name)
    AllOps.delete(name)
    Commands.delete(name)
  end
  if AST === node
    ir = create_ir_and_set_vars(node,context,last)
  else # IR
    ir = node
  end
  context[name] = ir
end

def get(context,name,from)
  return context[name] if context[name]
  warn "using unset var",from if $warn_on_unset_vars
  if numeral = to_roman_numeral(name)
    type = Num
    impl = numeral
  elsif name.size>1
    if Commands[name] || AllOps[name]
      warn("using %p as identifier string even though it is an op" % name, from)
    end
    type = Str
    impl = str_to_lazy_list(name)
  else
    type = Char
    impl = name[0].ord
  end
  IR.new(create_op(name: "data",type: type,impl: impl),from,[])
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
