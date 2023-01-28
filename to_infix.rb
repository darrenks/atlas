class AST
  attr_accessor :var_name
  attr_accessor :references
end

def count_references(node,nodes,type_info)
  if node.references != nil
    node.references += 1
    return
  end
  nodes << node
  node.references = 1
  rargs = type_info ? node.replicated_args : node.args
  rargs.each{|t| count_references(t,nodes,type_info) }
end


# todo, calculate best spot to define var to minimize parens

def to_infix(root, type_info:true)
  nodes = []
  count_references(root,nodes,type_info)
  $vars = 0
  ret=r(root, false, type_info, true)
  #cleanup
  nodes.each{|node|node.var_name = node.references = nil }
  ret
end

def r(node, is_rhs, type_info, first=false)
  return node.from_var if node.from_var && !first
  return node.var_name if node.var_name # todo shouldn't be needed anymore
  node.var_name = "v#{$vars+=1}" if node.references > 1 && !node.var_name && !node.from_var

  op_name = (node.op.sym||(" "+node.op.name+" ")).to_s
  op_name = "then " if node.op.name == "then"
  op_name = "‿" if node.op.sym == " " # todo and type inferred/promoted already

  op = "!" * (type_info ? node.zip_level : node.explicit_zip_level) + op_name
  op = " then " if op == "then "

  name_it = node.var_name ? ":" + node.var_name : ""
  rargs = type_info ? node.replicated_args : node.args

  expr = case rargs.size
  when 0
    op
  when 1
    r(rargs[0], false, type_info) + op
  when 2
    r(rargs[0], false, type_info) + op + r(rargs[1], true, type_info)
  when 3 # only if statement is 3
    r(rargs[0], false, type_info) + op + r(rargs[1], false, type_info) + " else " + r(rargs[2], true, type_info)
  else error
  end
  statement = expr + name_it
  maybe_paren(statement, (node.var_name ? 1 : 0) + rargs.size > 0 && is_rhs)
end

def maybe_paren(statement,maybe)
  maybe ? "(" + statement + ")" : statement
end
