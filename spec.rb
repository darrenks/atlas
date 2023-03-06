# general type vars
A = :a
B = :b

# type var of base elem char
Achar = :a_char

# type var of base elem int
Aint = :a_int

# type spec ================================
# { from => to } or just "to" if no args
# fyi you can't use [type] unless you mean list of type (doesn't mean 1)
# to can be a list for multiple rets or a type
# from can be a list for multiple args or a conditional type
# conditional type can be a type or a type qualifier of a type
# type can be an actual type or a list of a type (recursively) or a type var e.g. :a
class FnType < Struct.new(:specs,:ret,:orig_key,:orig_val)
  def inspect
    specs.map(&:inspect)*" "+" -> "+parse_raw_arg_spec(ret).inspect
  end
end

class VecOf < Struct.new(:of)
end

def create_specs(raw_spec)
  case raw_spec
  when Hash
      raw_spec.map{|raw_arg,ret|
        specs = (x=case raw_arg
          when Array
            if raw_arg.size == 1
              [raw_arg]
            else
              raw_arg
            end
          else
            [raw_arg]
          end).map{|a_raw_arg| parse_raw_arg_spec(a_raw_arg) }
        FnType.new(specs,ret,raw_arg,ret)
      }
  when Type, Array, VecOf, Symbol
    [FnType.new([],raw_spec,[],raw_spec)]
  else
    raise "unknown fn type format"
  end
end

def parse_raw_arg_spec(raw,list_nest_depth=0)
  case raw
  when Symbol
    VarTypeSpec.new(raw,list_nest_depth)
  when Array
    raise if raw.size != 1
    parse_raw_arg_spec(raw[0],list_nest_depth+1)
  when VecOf
    r=parse_raw_arg_spec(raw.of)
    r.vec_of=true
    r
  when Type
    ExactTypeSpec.new(raw.dim+list_nest_depth, raw)
  else
    p raw
    error
  end
end

class ExactTypeSpec
  attr_reader :req_dim
  attr_reader :type
  attr_accessor :vec_of
  def initialize(req_dim, type)
    @req_dim = req_dim
    @type = type
  end
  def check_base_elem(uses,type)
    type.can_base_be(@type)
  end
  def inspect
    (vec_of ? "<" : "")+type.inspect+(vec_of ? ">" : "")
  end
end

class VarTypeSpec
  attr_reader :var_name
  attr_reader :extra_dims
  attr_accessor :vec_of
  def initialize(var_sym, extra_dims) # e.g. [[a]] is .new(:a, 2)
    @var_name,@var_constraint = name_and_constraint(var_sym)
    @extra_dims = extra_dims
    @vec_of = false
  end
  def check_base_elem(uses,type)
    if @var_constraint
      @var_constraint == type.base_elem.to_s
    else
      type.base_elem == Unknown.base_elem || (uses[var_name]||=type.base_elem) == type.base_elem
    end
  end
  def inspect
    (vec_of ? "<" : "")+"["*extra_dims+var_name.to_s+"]"*extra_dims+(vec_of ? ">" : "")
  end
end

def name_and_constraint(var_sym)
  s = var_sym.to_s.split("_")
  [s[0].to_sym, s[1]]
end

def spec_to_type(spec, vars)
  case spec
  when Type
    TypeWithVecLevel.new(spec,0)
  when Array
    raise "cannot return multiple values for now" if spec.size != 1
    TypeWithVecLevel.new(spec_to_type(spec[0], vars).type + 1, 0)
  when Symbol
    name,constraint=name_and_constraint(spec)
    t=TypeWithVecLevel.new(vars[name],0)
    t.type.base_elem = constraint.to_sym if constraint
    t
  when VecOf
    TypeWithVecLevel.new(spec_to_type(spec.of, vars).type, 1)
  else
    unknown
  end
end
