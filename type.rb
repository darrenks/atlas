Type = Struct.new(:dim,:is_char)
class Type
  def inspect
    "["*dim+ (is_char ? "Char" : "Int") + "]"*dim
  end
  def -(rhs)
    self.dim - rhs.to_i
  end
  def +(zip_level)
    Type.new(dim+zip_level, is_char)
  end
  def to_i
    dim
  end
  def <=>(rhs)
    self.dim - rhs.dim
  end
  def list_of
    Type.new(dim+1,is_char)
  end
  def elem
    raise "internal type error, can't take elem of %p" % self if dim < 1
    Type.new(dim-1,is_char)
  end

end

Int = Type.new(0,false)
Char = Type.new(0,true)
Str = Type.new(1,true)

def max_dim(t1,t2)
  [t1.dim,t2.dim].max
end

