class AST
  attr_accessor :var_name
  attr_accessor :references
end

def to1d(root)
  root = root.args[0] if root.op.token.str == "O"
  nodes = []
  count_references(root,nodes)
  $vars = 0
  ret=trace1d(root)
  #cleanup
  nodes.each{|node|node.var_name = nil; node.references = nil }
  [ret,nodes.size]
end

def count_references(node,nodes)
  if node.references != nil
    node.references += 1
    return
  end
  nodes << node
  node.references = 1
  node.args.each{|t| count_references(t,nodes) }
end

def trace1d(node)
  if node.var_name
    return node.var_name
  end
  node.var_name = "v#{$vars+=1}" if node.references > 1
  args1d = node.args.map{|t| trace1d(t) }
  (node.var_name ? [node.var_name + "="] : []) + [node.op.str] + args1d
end