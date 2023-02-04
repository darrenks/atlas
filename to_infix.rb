# define infix_args, from, op, zip_level to make this work
module ToInfix
  def to_infix(is_rhs=false)
    return "$" if from && from.token && from.token.str == :EOL

    op_name = (op.sym||(" "+op.name+" ")).to_s
    op_name = "then " if op.name == "then"
    op_name = "‿" if op.sym == " " # todo and type inferred/promoted already
    op = "!" * zip_level + op_name
    op = " then " if op == "then "

    a = infix_args
    expr = case a.size
    when 0
      from.token.str
    when 1
      a[0].to_infix + op
    when 2
      a[0].to_infix + op + a[1].to_infix(true)
    when 3 # only if statement is 3
      a[0].to_infix + op + a[1].to_infix + " else " + a[2].to_infix(true)
    else error
    end
    maybe_paren(expr, a.size > 0 && is_rhs)
  end

end
class String # this is here so that from_var can return string
  def to_infix(is_rhs=false)
    self
  end
end

class IR
  def infix_args
    replicated_args.map.with_index{|arg,i|
      arg.from_var ? arg.from_var : arg
    }
  end
  include ToInfix
end

class AST
  def from
    self
  end
  alias infix_args args
  def zip_level
    explicit_zip_level + (pre_zip_level || 0)
  end
  include ToInfix
end

def maybe_paren(statement,maybe)
  maybe ? "(" + statement + ")" : statement
end
