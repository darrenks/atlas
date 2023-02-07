# Set this to default because these get used a bit during parse (e.g. creating a string)
$step_limit=Float::INFINITY
$reductions = 0

'
Instructions for using CPS trampolined style definitions:
you may only return thunks
calling a continuation returns a thunk
promise.get_value returns a thunk

if you use recursion you should put the recursive call inside a new thunk unless you know for a fact it will be called only to a constant depth (I think)

I\'m not 100% sure that all of these new thunks are necessary, should do some testing and checking max stack depth. For now error on side of safety.

The purpose of all this complexity is to avoid arbitrary recursion depth which would stack overflow on biggish data (around size 1000 lists).
'


class Thunk
  def initialize(&fn)
    @fn=fn
  end
  def go
    @fn.call
  end
end

class Proc
  def cont(arg)
    Thunk.new{ call arg }
  end
end


def run(root,out=STDOUT,output_limit=10000,step_limit=Float::INFINITY)
  $step_limit = step_limit
  $reductions = 0
  #root = root.replicated_args[0] #rm tostring
  ret = proc{|_| return }

  thunk = Thunk.new{
    print_string(make_promises(root), out, output_limit, ret)
  }
  loop { thunk = thunk.go }
end

def make_promises(node)
  return node.promise if node.promise
  arg_types = node.replicated_args.map{|arg|arg.type-node.zip_level}
  args = nil
  node.promise = Promise.new { |cont|
    zipn(node.zip_level, args, node.op.impl[arg_types, node], cont)
  }
  args = node.replicated_args.map{|arg| make_promises(arg) }
  node.promise
end

class Promise
  attr_accessor :expect_non_empty
  def initialize(&block)
    @impl=block
  end
  def value
    $reductions+=1
    raise DynamicError.new "step limit exceeded",nil if $reductions > $step_limit
    if Proc===@impl
      raise InfiniteLoopError.new "infinite loop detected",self,nil if @calculating # todo fix from location
      @calculating=true
      begin
        @impl=@impl[]
      ensure
        # not really needed since new promises are created rather than reused
        @calculating=false
      end
      raise InfiniteLoopError.new "infinite loop detected2",self,nil if expect_non_empty && @impl == []
    end
    @impl
  end
  def get_value(&cont)
    if Proc===@impl
#         @impl[lambda{|v|@impl=v;Thunk.new{cont[v]}}]
      @impl[->v { @impl = v; cont.cont v }]
    else
      cont.cont(@impl)
    end
  end
  def ret_value(cont) # todo use this more, but is it even necessary??
    get_value{|i|cont.cont i}
  end
  def inspect
    "promise"
  end
end

# A simple promise that just returns the result of an atomic operation
def spromise(&b)
  Promise.new{|cont|cont.cont b[]}
end

def take(n, a, cont)
  if n <= 0
    cont.cont []
  else
    a.get_value{|av|
      if av == []
        cont.cont []
      else
        cont.cont [av[0], Promise.new{|c2| take(n-1, av[1], c2) }]
      end
    }
  end
end

def drop(n, a)
  while n>0 && a.value != []
    n-=1
    a=a.value[1]
  end
  a.value
end

def init(a)
  raise DynamicError.new "init on empty list",nil if a==[]
  return [] if a[1].value == []
  [a[0], Promise.new{ init(a[1].value) }]
end

# value -> (value -> Promise) -> value
def map(a,&b)
  a==[] ? [] : [b[a[0].value], Promise.new{map(a[1].value,&b)}]
end

# value -> value
# truncate as soon as encounter empty list
def trunc(a)
  a == [] || a[0].value == [] ? [] : [a[0], Promise.new{trunc(a[1].value)}]
end

def transpose(a)
  return [] if a==[]
  return transpose(a[1].value) if a[0].value == []
  broken = trunc(a[1].value)
  hds = Promise.new{ map(broken){|v|v[0]} }
  tls = Promise.new{ map(broken){|v|v[1]} }
  [Promise.new{[a[0].value[0],hds]},
   Promise.new{transpose [a[0].value[1],tls]}]
end

def last(a,cont,prev=nil)
  if a.empty?
    prev.get_value{|pv|cont.cont pv}
  else
    a[1].get_value{|a1v|
      Thunk.new{ last(a1v,cont,a[0]) }
    }
  end
end



# n = int number of dims to zip
# a = args, [promise]
# f = impl, promises -> value
# returns value
def old_zipn(n,a,f,c)
  return f[*a,c] if n <= 0 || a==[]
  faith = []
  return [] if a.any?{|i|
    begin
      i.value==[]
    rescue InfiniteLoopError => e
      raise e unless e.source == i
      # gotta have faith
      # solves this type of problem: a=!:,0 +a ::1;2;:3;4
      faith << i
      false # not empty
    end
  }
  faith.each{|i| i.expect_non_empty = true }
  [Promise.new{zipn(n-1,a.map{|i|i.value[0]},f) },
   Promise.new{zipn(n,a.map{|i|i.value[1]},f) }]
end

def zipn(n,a,f,c)
  return f[*a,c] if n <= 0 || a==[]
  getn_values(a,c) {|av|
    [Promise.new{|c2|          zipn(n-1,av.map{|i|i[0]},f,c2) },
     Promise.new{|c2|Thunk.new{zipn(n,  av.map{|i|i[1]},f,c2)} }]
  }
end

def getn_values(a,c,i=0,av=[],&b)
  if i>=a.size
    c.cont(yield(av))
  else
    a[i].get_value{|aiv|
      if aiv == []
        c.cont []
      else
        getn_values(a,c,i+1,av<<aiv,&b)
      end
    }
  end
end

def repeat(a)
  ret = [a]
  ret << spromise{ret}
  ret
end

def pad(a,b)
  [
    Promise.new{ a.value == [] ? b.value : a.value[0].value },
    Promise.new{ pad( Promise.new{ a.value == [] ? [] : a.value[1].value }, b) }
  ]
end

# value -> value -> value
def equal(a,b,t)
  if t.dim>0
    return true if a==[] && b==[]
    return false if a==[] || b==[]
    return equal(a[0].value,b[0].value,t-1) && equal(a[1].value,b[1].value,t)
  else
    a==b
  end
end

def len(a)
  return 0 if a==[]
  return 1+len(a[1].value)
end

# value -> Promise -> value
def append(v,r,cont)
  v==[] ? r.get_value{|rv|cont.cont rv} : cont.cont([v[0],Promise.new{|c2|v[1].get_value{|v1v|Thunk.new{append(v1v, r, c2)}}}])
  #concat_map(v,r){|v2,r2|[Promise.new{v2},r2]}
end

# value -> value -> bool -> (value -> promise -> ... -> value) -> value
def concat_map(v,rhs,cont,first=true,&b)
  if v==[]
    cont.cont rhs
  else
    v[0].get_value{|v0v|
      b[v0v,Promise.new{|c2|
        v[1].get_value{|v1v|
          Thunk.new{concat_map(v1v,rhs,c2,false,&b)}
        }
      },first,cont]
    }
  end
end

def inspect_value(t,value,cont)
  inspect_value_h(t,value,Null,cont)
end

def inspect_value_h(t,value,rhs,cont)
  if t == Nil
    str_to_lazy_list("[]",cont,rhs)
  elsif t==Str
    cont.cont [spromise{'"'.ord}, Promise.new{|c2|
      str_to_lazy_list('"',lambda{|quote|
        concat_map(value,quote,c2){|v,r,first,c3|
          str_to_lazy_list(escape_str_char(v),c3,r)
        }
      }, rhs)
    }]
  elsif t==Int
    str_to_lazy_list(value.to_s,cont,rhs)
  elsif t==Char
    str_to_lazy_list(inspect_char(value),cont,rhs)
  else #List
    cont.cont [spromise{"[".ord}, Promise.new{|c2|
      str_to_lazy_list("]",lambda{|quote|
        concat_map(value,quote,c2){|v,r,first,c3|
          first ?
            inspect_value_h(t-1,v,r,c3) :
            c3.cont([spromise{','.ord},Promise.new{|c4|inspect_value_h(t-1,v,r,c4)}])
        }
      },rhs)
    }]
  end
end

def to_string(t, a, cont)
  a.get_value{|v| to_string_h(t,v,t.string_dim,Null,cont) }
end

def to_string_h(t, value, orig_dim, rhs,cont)
  if t == Int
    inspect_value_h(t, value, rhs, cont)
  elsif t == Char
    cont.cont [spromise{value}, rhs]
  else # List
    dim = t.string_dim
    separator = [""," ","\n"][dim] || "\n\n"
    # this would make the lang a bit better on golf.shinh.org but not intuitive
    #separator = "\n" if orig_dim == 1 && dim == 1
    rhs.get_value{|rhsv|
      concat_map(value,rhsv,cont){|v,r,first,c2|
        svalue = Promise.new{|c3| to_string_h(t-1, v, orig_dim, r, c3) }
        first ? svalue.get_value{|sv|c2.cont sv} : str_to_lazy_list(separator, c2, svalue)
      }
    }
  end
end

def print_string(str, out, limit, cont)
  str.get_value{|v|
    if v != [] && limit > 0
      v[0].get_value{|v0v|
        out.print "%c" % v0v
        Thunk.new { print_string(v[1], out, limit-1, cont) }
      }
    else
      cont.cont nil
    end
  }
end

# string value -> int value
def read_int(s)
  multiplier=1
  until s==[] || s[0].value.chr =~ /[0-9]/
    if s[0].value == ?-.ord
      multiplier *= -1
    else
      multiplier = 1
    end
    s = s[1].value
  end
  v = 0
  found_int = false
  until s==[] || !(s[0].value.chr =~ /[0-9]/)
    found_int = true
    v = v*10+s[0].value-48
    s = s[1].value
  end
  [multiplier * v, found_int, s]
end

# string value -> [string] value
def lines(s)
  return [] if s==[]

  after = Promise.new{lines(s[1].value)}
  if s[0].value == 10
    [Null, after]
  else
    [Promise.new{
      after.value == [] ? [s[0], Null] : [s[0], after.value[0]]
     },
     Promise.new{
      after.value == [] ? [] : after.value[1].value
     }]
   end
end

# string value -> [int] value
def split_non_digits(s)
  return [] if s==[]
  v,found,s2=read_int(s)
  return [] if !found
  [Promise.new{v},Promise.new{split_non_digits(s2)}]
end

ReadStdin = Promise.new{ read_stdin }
def read_stdin
  c=STDIN.getc
  if c.nil?
    []
  else
    [Promise.new{ c.ord }, Promise.new{ read_stdin }]
  end
end

Null = spromise{ [] }

def str_to_lazy_list(s,cont,rhs=Null)
  to_lazy_list(s.chars.map(&:ord), cont, rhs)
end

def to_lazy_list(l, cont, rhs=Null, ind=0)
  ind >= l.size ? rhs.get_value{|e|cont.cont e} : cont.cont([spromise{l[ind]}, Promise.new{|cont2|to_lazy_list(l, cont2, rhs, ind+1)}])
end
