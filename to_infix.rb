class AST
  attr_accessor :var_name
  attr_accessor :references
  def rargs
    replicated_args || args
  end
end

def count_references(node,nodes)
  if node.references != nil
    node.references += 1
    return
  end
  nodes << node
  node.references = 1
  node.rargs.each{|t| count_references(t,nodes) }
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

def r(node, is_rhs)
  return node.var_name if node.var_name
  node.var_name = "v#{$vars+=1}" if node.references > 1 && !node.var_name

  op_name = (node.op.sym||(" "+node.op.name+" ")).to_s
  op_name = "then" if node.op.name == "then"
  op_name = "‿" if node.op.sym == " " # todo and type inferred/promoted already

  op = "!" * (node.zip_level || node.explicit_zip_level) + op_name

  name_it = node.var_name ? ":" + node.var_name : ""
  expr = case node.rargs.size
  when 0
    op
  when 1
    r(node.rargs[0], false) + op
  when 2
    r(node.rargs[0], false) + op + r(node.rargs[1], true)
  when 3 # only if statement is 3
    r(node.rargs[0], false) + " then " + r(node.rargs[1], false) + " else " + r(node.rargs[2], true)
  else error
  end
  statement = expr + name_it
  maybe_paren(statement, (node.var_name ? 1 : 0) + node.rargs.size > 0 && is_rhs)
end

def maybe_paren(statement,maybe)
  maybe ? "(" + statement + ")" : statement
end
