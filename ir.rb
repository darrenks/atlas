$ir_node_count = 0
class IR < Struct.new(
    :op,                  # these set during construction
    :orig_args,
    :from,
    :type,                # this and rest calculted in infer
    :zip_level,
    :promise,
    :id,
    :used_by,
    :replicated_args,
    :last_error,
    :from_var)
  def initialize(*args)
    super(*args)
    self.id = $ir_node_count += 1
  end
  def explicit_zip_level
    from ? from.explicit_zip_level : 0
  end
end

# creates an IR from an AST, replacing vars
def to_ir(ast,context,result_name=nil)
  ir = create_ir(ast,context)
  context[result_name] = ir if result_name # for circular
  check_missing(ir,context,{})
  ir = lookup_vars(ir,context,{})
  ir
end

def set(t,ast,context)
  ir = context[t.str] = create_ir(ast, context)
  ir.from_var = t.str
  ir
end


def create_ir(node,context) # and register_vars
  if node.op.name == "let"
    raise ParseError.new("only identifiers may be set",node) if node.args[1].op.name != "var"
    set(node.args[1].token, node.args[0], context)
  else
    args=node.args.map{|arg|create_ir(arg,context)}
    IR.new(node.op,args,node)
  end
end

def check_missing(node,context,been)
  return node if been[node.id]
  been[node.id]=true
  if node.op.name == "var"
    name = node.from.token.str
    raise(ParseError.new("unset identifier %p" % name, node.from.token)) unless context.include? name
    raise(ParseError.new("trivial self dependency is nonsensical", node.from.token)) if context[name] == node
    check_missing(context[name],context,been)
  else
    node.orig_args.each{|arg| check_missing(arg, context,been) }
  end
end

def lookup_vars(node,context,been)
  return node if been[node.id]
  been[node.id]=true
  node.orig_args.map!{|arg| lookup_vars(arg, context,been) }
  if node.op.name == "var"
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
    node.orig_args.each{|arg|
      dfs_helper(arg,been,cycle_fn,post_fn)
    }
    post_fn[node]
  end
  been[node.id] = Status::SEEN
  return
end
