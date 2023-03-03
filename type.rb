Inf = 2**61 # for max_pos_dim
Type = Struct.new(:dim,:base_elem) # base is :int, :char, or :nil
# for now :nil 0 = unknown type, [Nil] means list of unknown type aka empty list
TypeWithVecLevel = Struct.new(:type,:vec_level)

class Type
  def inspect
    return "(%d %s)"%[dim,base_elem] if dim < 0 # ret nicely since could have negative type errors in circular inference that later becomes valid
    "["*dim + base_elem.to_s.capitalize + "]"*dim
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
  def default_value
    return [] if dim > 0
    return 32 if is_char
    return 0
  end
end

Int = Type.new(0,:int)
Char = Type.new(0,:char)
Str = Type.new(1,:char)
Nil = Type.new(1,:nil)
NilV0 = TypeWithVecLevel.new(Nil,0)

class TypeWithVecLevel
  def inspect
    return "(%d %s)"%[vec_level,type.inspect] if vec_level < 0 # ret nicely since could have negative type errors in circular inference that later becomes valid
    "<"*vec_level + type.inspect + ">"*vec_level
  end
end

