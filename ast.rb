$ast_node_count = 0

class AST < Struct.new(:op,:args,:token,:type,:zip_level,:promise,:id,:used_by,:replicated_args,:last_error,:replaced)
  def initialize(*args)
    super(*args)
    self.id = $ast_node_count += 1
  end
  def explicit_zip_level
    token ? token.str[/^!*/].size : 0
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
