class AST
  attr_accessor :var_name
  attr_accessor :references
end

def to1d(root,with_types = false)
  root = root.args[0] if root.op.token.str == "O"
  nodes = []
  count_references(root,nodes)
  $vars = 0
  ret=trace1d(root,with_types)
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

def trace1d(node,with_types)
  if node.var_name
    return node.var_name
  end
  node.var_name = "v#{$vars+=1}" if node.references > 1
  args1d = node.args.map{|t| trace1d(t,with_types) }
  (node.var_name ? [node.var_name + "="] : []) + (node.type && with_types ? [node.type.inspect] : []) + ["!" * (node.zip_level || node.op.explicit_zip_level) + node.op.sym] + args1d
end