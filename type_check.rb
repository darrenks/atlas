def type_check(node)
  return if node.been_type_checked
  node.been_type_checked = true

  _,_,_,checker = node.op.behavior[node.op.token]
  node.type.value # calculate root code too...
  if checker
    arg_types = node.args.map{|n|n.type.value}
    checker[*arg_types]
  end
  node.args.each{|n| type_check(n) }
end

class AST
  attr_accessor :been_type_checked
end