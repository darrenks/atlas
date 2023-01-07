Inf = 2**61 # for max_pos_dim
Type = Struct.new(:dim,:base_elem) # base is :int, :char, or :nil

class Type
  def inspect
    d = is_nil ? dim-1 : dim
    return "(%d %s)"%[dim,base_elem] if d < 0
    "["*d + base_elem.to_s.capitalize + "]"*d
  end
  def -(rhs)
    self+-rhs
  end
  def +(zip_level)
    Type.new(dim+zip_level, base_elem)
  end
  def max_pos_dim
    is_nil ? Inf : dim
  end
  def string_dim # dim but string = 0
    dim + (is_char ? -1 : 0)
  end
  def is_char
    base_elem == :char
  end
  def is_nil
    base_elem == :nil
  end
  def can_base_be(rhs) # return true if self can be rhs
    return self.base_elem == rhs.base_elem
  end
  def |(rhs)
    Type.new([dim, rhs.dim].min, base_elem == rhs.base_elem ? base_elem : :nil)
  end
end

Int = Type.new(0,:int)
Char = Type.new(0,:char)
Str = Type.new(1,:char)
Nil = Type.new(1,:nil)

