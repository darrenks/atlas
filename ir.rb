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
  def get_value # get internal int value
    infer(self)
    raise AtlasTypeError.new("var must be type Int",self) if self.type != Int || self.vec_level != 0
    make_promises(self).value
  end
end

# creates an IR from an AST, replacing vars
def to_ir(ast,context)
  ir = create_ir(ast,context)
  ir = check_missing(ir,context,{})
  ir = lookup_vars(ir,context,{})
  ir
end

def set(t,ast,context)
  context[t.str] = create_ir(ast, context)
  $reductions = context[t.str].get_value if t.str == "reductions"
  context[t.str]
end

def create_ir(node,context) # and register_vars
  if node.op.name == "let"
    raise ParseError.new("only identifiers may be set",node) if node.args[1].op.name != "var"
    set(node.args[1].token, node.args[0], context)
  else
    args=node.args.map{|arg|create_ir(arg,context)}
    op = node.op.dup
    if node.token && node.token.str =~ /#{FlipRx}$/
      args.reverse!
    end
    IR.new(op,args,node)
  end
end

def check_missing(node,context,been)
  return node if been[node.id]
  been[node.id]=true
  if node.op.name == "var"
    name = node.from.token.str
    if !context.include? name
      if context["golfMode"].get_value != 0
        if name.size>1
          return IR.new(create_op(
            name: "data",
            type: Str,
            impl: str_to_lazy_list(name)),[],node.from)
        else
          return IR.new(create_op(
            name: "data",
            type: Char,
            impl: name[0].ord),[],node.from)
        end
      else
        raise(ParseError.new("unset identifier %p" % name, node.from.token))
      end
    end
    #raise(ParseError.new("trivial self dependency is nonsensical", node.from.token)) if context[name] == node
    check_missing(context[name],context,been)
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
    return IR.new(UnknownOp,[],node.from) if context[node.from.token.str] == node
    lookup_vars(context[node.from.token.str],context,been)
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

