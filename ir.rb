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
    raise ParseError.new("only identifiers may be set",node) if node.args[1].op.name != "var" # todo similar check to let in repl but done differently
    set(node.args[1].token, node.args[0], context,last)
  elsif node.op.name == "save"
    vars = [*'a'..'z']-context.keys
    raise(ParseError.new("out of vars", node)) if vars.empty?
    set(Token.new(vars[0]),node.args[0],context,last)
  elsif node.op.name == "ans"
    raise ParseError.new("there is no last ans to refer to",node) if !last
    last
  else
    args=node.args.map{|arg|create_ir_and_set_vars(arg,context,last)}
    op = node.op.dup # todo why dup??
    args.reverse! if node.is_flipped
    IR.new(op,node,args)
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

def set(t,ast,context,last)
  name = t.str
  raise ParseError.new("cannot set %p, it is not a name" % name, t) unless IdRx =~ name
  Ops0.delete(name)
  Ops1.delete(name)
  Ops2.delete(name)
  AllOps.delete(name)
  Commands.delete(name)
  context[name] = create_ir_and_set_vars(ast,context,last)
end

def get(context,name,from)
  return context[name] if context[name]
  if numeral = to_roman_numeral(name)
    type = Num
    impl = numeral
  elsif name.size>1
    type = Str
    impl = str_to_lazy_list(name)
  else
    type = Char
    impl = name[0].ord
  end
  IR.new(create_op(name: "data",type: type,impl: impl),from,[])
end
