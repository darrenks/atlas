# -*- coding: ISO-8859-1 -*-
$ir_node_count = 0
class IR < Struct.new(
    :op,                  # these set during construction
    :args,
    :from,
    :type_with_vec_level, # this and rest calculted in infer
    :zip_level,
    :promise,
    :id,
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

# creates an IR from an AST, replacing vars
def to_ir(ast,context,saves)
  ir = create_ir(ast,context,saves)
  set_saves(context,saves)
  ir = check_missing(ir,context,{})
  ir = lookup_vars(ir,context,{})
  ir
end

def set(t,ast,context,saves)
  raise ParseError.new("cannot set %p, it is not a name" % t.str) unless IdRx =~ t.str
  Ops0.delete(t.str)
  Ops1.delete(t.str)
  Ops2.delete(t.str)
  AllOps.delete(t.str)
  Commands.delete(t.str)
  context[t.str] = create_ir(ast, context,saves)
end

def create_ir(node,context,saves) # and register_vars
  if node.op.name == "set"
    raise ParseError.new("only identifiers may be set",node) if node.args[1].op.name != "var" # todo similar check to let in repl but done differently
    set(node.args[1].token, node.args[0], context, saves)
  elsif node.op.name == "save"
    # we don't know what future vars will be set, we don't want to use those names, so don't do anything yet
    v = create_ir(node.args[0], context, saves)
    saves << v
    v
  else
    args=node.args.map{|arg|create_ir(arg,context,saves)}
    op = node.op.dup
    args.reverse! if node.is_flipped
    IR.new(op,args,node)
  end
end

def set_saves(context,saves)
  vars = [*'a'..'z'] - context.keys
  saves.each{|node|
    raise(ParseError.new("out of vars", node)) if vars.empty?
    context[vars.shift] = node
  }
  saves.replace([])
end

def check_missing(node,context,been)
  return node if been[node.id]
  been[node.id]=true
  if node.op.name == "var"
    name = node.from.token.str
    if !context.include? name
      warn("unset identifier %p" % name, node.from.token) if context.keys.any?{|v|!v['_'] && v.size > 1} # "_" is to not count internal vars
      node
    else
      check_missing(context[name],context,been)
    end
  else
    node.args.map!{|arg| check_missing(arg, context,been) }
    node
  end
end

def lookup_vars(node,context,been)
  return node if been[node.id]
  been[node.id]=true if node.op.name != "var"
  node.args.map!{|arg| lookup_vars(arg, context,been) }
  if node.op.name == "var"
    name = node.from.token.str
    val = context[name]
    if val == nil
      if (numeral = to_roman_numeral(name))
        IR.new(create_op(
          name: "data",
          type: Num,
          impl: numeral),[],node.from)
      elsif name.size>1
        IR.new(create_op(
          name: "data",
          type: Str,
          impl: str_to_lazy_list(name)),[],node.from)
      else
        IR.new(create_op(
          name: "data",
          type: Char,
          impl: name[0].ord),[],node.from)
      end
    elsif context[node.from.token.str] == node
      IR.new(UnknownOp,[],node.from)
    else
      lookup_vars(context[node.from.token.str],context,been)
    end
  else
    node
  end
end

def all_nodes(root)
  all = []
  dfs(root){|node| all << node}
  all
end

module Status
  UNSEEN = 1 # in practice nil will be used
  PROCESSING = 2
  SEEN = 3
end

def dfs(root,cycle_fn:->_{},&post_fn)
  dfs_helper(root,[],cycle_fn,post_fn)
end

def dfs_helper(node,been,cycle_fn,post_fn)
  if been[node.id] == Status::SEEN

  elsif been[node.id] == Status::PROCESSING # cycle
    cycle_fn[node]
  else
    been[node.id] = Status::PROCESSING
    node.args.each{|arg|
      dfs_helper(arg,been,cycle_fn,post_fn)
    }
    post_fn[node]
  end
  been[node.id] = Status::SEEN
  return
end

