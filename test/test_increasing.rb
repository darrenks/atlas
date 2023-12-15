require "./repl.rb"

# todo consider errors
# todo consider trying to hone in on list dim first, vec levels could be invalid?

Types = 3.times.map{|vl|
  3.times.map{|ll|
    [:num,:char,:a].map{|base_elem|
      TypeWithVecLevel.new(Type.new(ll,base_elem),vl)
    }
  }
}.flatten

Memo = {}
def calc(op, arg_types)
  key = "%p %p" % [op.sym,arg_types]
  return Memo[key] if Memo.key? key
  args = arg_types.map{|type|
    arg=IR.new
    arg.type_with_vec_level = type
    arg.op = Op.new
    arg
  }
  node = IR.new(op,args)
  calc_type(node)
  return (Memo[key] = node.last_error ? nil : node.type_with_vec_level)
end

# Test list dims only increase list dims regardless of vec levels

#1 arg
Ops1.values.each{|op|
  Types.each{|t1|
    r = calc(op, [t1])
    next unless r
    3.times{|vec_level|
      r2 = calc(op, [TypeWithVecLevel.new(t1.type+1, vec_level)])
      raise if r2 && r.type.dim>r2.type.dim
    }
  }
}

# 2 arg

Ops2.values.each{|op|
  next if op.sym == ";" # to/fromBase is special, I am ok with this causing issues if used in circular programming as it is unlikely to be used that way, this exception allows it to be overloaded for to or from a base.
  Types.each{|t1|
    Types.each{|t2|
      r = calc(op, [t1,t2])
      next unless r
      (1..3).each{|b|
        3.times{|v1|3.times{|v2|
        args = [TypeWithVecLevel.new(t1.type+b[0], v1),
                TypeWithVecLevel.new(t2.type+b[1], v2)]
        r2 = calc(op, args)
        if r2 && r.type.dim>r2.type.dim
          p op.sym
          p '%p %p -> %p' % [t1,t2,r]
          p '%p %p -> %p' % [args[0],args[1],r2]
          raise
        end
        }}
      }
    }
  }
}

# Test vec dims only increase vec dims and do not change list dims

#1 arg
Ops1.values.each{|op|
  Types.each{|t1|
    r = calc(op, [t1])
    next unless r
    r2 = calc(op, [TypeWithVecLevel.new(t1.type, t1.vec_level+1)])

    if r2 && r.type.dim!=r2.type.dim
      p op.name
      puts "#{t1.inspect} -> #{r.inspect}"
      puts "#{TypeWithVecLevel.new(t1.type, t1.vec_level+1).inspect} -> #{r2.inspect}"
      raise
    end
    raise if r2 && r.vec_level>r2.vec_level
  }
}

Ops2.values.each{|op|
  Types.each{|t1|
    Types.each{|t2|
      r = calc(op, [t1,t2])
      next unless r
      (1..3).each{|b|
        args = [TypeWithVecLevel.new(t1.type, t1.vec_level+b[0]),
                TypeWithVecLevel.new(t2.type, t2.vec_level+b[1])]
        r2 = calc(op, args)
        if r2 && r.type.dim!=r2.type.dim
          p op.sym
          p '%p %p -> %p' % [t1,t2,r]
          p '%p %p -> %p' % [args[0],args[1],r2]
          raise
        end
        raise if r2 && r.vec_level>r2.vec_level
      }
    }
  }
}