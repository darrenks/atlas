Inf = 2**61 # for max_pos_dim
Type = Struct.new(:dim,:base_elem) # base is :num, :char, or :a
# :a means unknown type, it could be any type with dim >= 0
TypeWithVecLevel = Struct.new(:type,:vec_level)

class Type
  def inspect
    #return "(%d %s)"%[dim,base_elem] if dim < 0 # ret nicely since could have negative type errors in circular inference that later becomes valid
    "["*dim + (base_elem.to_s.size>1 ? base_elem.to_s.capitalize : base_elem.to_s) + "]"*dim
  end
  def -(rhs)
    self+-rhs
  end
  def +(zip_level)
    Type.new(dim+zip_level, base_elem)
  end
  def max_pos_dim
    is_unknown ? Inf : dim
  end
  def string_dim # dim but string = 0
    dim + (is_char ? -1 : 0)
  end
  def is_char
    base_elem == :char
  end
  def is_unknown
    base_elem == :a
  end
  def can_base_be(rhs) # return true if self can be rhs
    return self.base_elem == rhs.base_elem
  end
  def default_value
    return [] if dim > 0
    return 32 if is_char
    return 0 if base_elem == :num
    raise DynamicError.new("access of the unknown type",nil)
  end
end

Num = Type.new(0,:num)
Char = Type.new(0,:char)
Str = Type.new(1,:char)
Unknown = Type.new(0,:a)
UnknownV0 = TypeWithVecLevel.new(Unknown,0)
Empty = Unknown+1

class TypeWithVecLevel
  def inspect
    #return "(%d %s)"%[vec_level,type.inspect] if vec_level < 0 # ret nicely since could have negative type errors in circular inference that later becomes valid
    "<"*vec_level + type.inspect + ">"*vec_level
  end
end

