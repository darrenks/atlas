A = :a
B = :b

# type spec ================================
# { from => to } or just "to" if no args
# fyi you can't use [type] unless you mean list of type (doesn't mean 1)
# to can be a list for multiple rets or a type
# from can be a list for multiple args or a conditional type
# conditional type can be a type or a type qualifier of a type
# type can be an actual type or a list of a type (recursively) or a type var e.g. :a
class FnType < Struct.new(:specs,:ret)
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
        FnType.new(specs,ret)
      }
  when Type, Array
    [FnType.new([],raw_spec)]
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
  def initialize(req_dim, type)
    @req_dim = req_dim
    @type = type
  end
  def check_base_elem(type)
    type.can_base_be(@type)
  end
end

class VarTypeSpec
  attr_reader :var_name
  attr_reader :extra_dims
  def initialize(var_name, extra_dims) # e.g. [[a]] is .new(:a, 2)
    @var_name = var_name
    @extra_dims = extra_dims
  end
  def check(type)
    return true
  end
  def check_base_elem(type)
    return true
  end
end

def spec_to_type(spec, vars)
  case spec
  when Type
    spec
  when Array
    raise "cannot return multiple values for now" if spec.size != 1
    spec_to_type(spec[0], vars) + 1
  when Symbol
    vars[spec]
  else
    p spec
    unknown
  end
end
