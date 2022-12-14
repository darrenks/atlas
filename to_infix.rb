class AST
  attr_accessor :var_name
  attr_accessor :references
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


# todo, calculate best spot to define var to minimize parens

def to_infix(root)
  nodes = []
  count_references(root,nodes)
  $vars = 0
  ret=r(root, false)
  #cleanup
  nodes.each{|node|node.var_name = node.references = nil }
  ret
end

Convert = '( ) ='.split

def r(node, is_lhs)
  return node.var_name if node.var_name
  node.var_name = "v#{$vars+=1}" if node.references > 1 && !node.var_name

  op_name = node.op.sym.to_s
  op_name = Convert.include?(op_name) ? ""+node.op.name+" " : op_name

  op = "!" * (node.zip_level || node.explicit_zip_level) + op_name

  name_it = node.var_name ? node.var_name + "=" : ""
  expr = case node.args.size
  when 0
    op
  when 1
    op + r(node.args[0], is_lhs)
  when 2
    r(node.args[0], true) + op + r(node.args[1], false)
  when 3
    r(node.args[0], true) + op + r(node.args[1], false) + ")" + r(node.args[2], false)
  else error
  end
  statement = name_it + expr
  (node.var_name ? 1 : 0) + node.args.size > 0 && is_lhs ?
    "(" + statement + ")" :
    statement
end

# todo look at ~5  it becomes _((~5)):"\n":$ which has extra parens