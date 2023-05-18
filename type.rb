Inf = 2**61 # for max_pos_dim
Type = Struct.new(:rank,:base) # base is :num, :char, :a
# :a means unknown type, it could be any type with dim >= 0

class Type
  def inspect
    #return "(%d %s)"%[dim,base_elem] if dim < 0 # ret nicely since could have negative type errors in circular inference that later becomes valid
    base_s = base.to_s.size>1 ? base.to_s.capitalize : base.to_s
    "["*rank + base_s + "]"*rank
  end
  def -(rhs)
    self+-rhs
  end
  def +(zip_level)
    Type.new(rank+zip_level, base)
  end
  def max_pos_dim
    is_unknown ? Inf : rank
  end
  def string_dim # dim but string = 0
    rank + (is_char ? -1 : 0)
  end
  def is_char
    base == :char
  end
  def is_unknown
    base == :a
  end
  def can_base_be(rhs) # return true if self can be rhs
    return self.base == rhs.base
  end
  def default_value
    return [] if rank > 0
    return 32 if is_char
    return 0 if base == :num
    raise DynamicError.new("access of the unknown type",nil)
  end
end

Num = Type.new(0,:num)
Char = Type.new(0,:char)
Str = Type.new(1,:char)
Unknown = Type.new(0,:a)
Empty = Unknown+1
