def run(root,n="\n",s=" ")
  v = Promise.new{yield(make_promises(root), n, s)}
  print_string(v,n)
end

def make_promises(node)
  return node.promise if node.promise
  arg_types = node.args.zip(0..).map{|a,i|a.type + a.vec_level - node.zip_level + node.rep_levels[i] + node.promote_levels[i]}
  args = nil
  node.promise = Promise.new {
    zipn(node.zip_level, args, node.op.impl[arg_types, node])
  }
  args = node.args.zip(0..).map{|arg,i|
    promoted = promoten(arg.vec_level, node.promote_levels[i], make_promises(arg))
    repn(arg.vec_level, node.rep_levels[i], promoted)
  }
  node.promise
end

class Promise
  attr_accessor :expect_non_empty
  def initialize(&block)
    @impl=block
  end
  def empty
    value==[]
  end
  def value
    if Proc===@impl
      begin
        raise InfiniteLoopError.new "infinite loop detected",self,nil if @calculating # todo fix from location
        @calculating=true
        @impl=@impl[]
      rescue DynamicError => e
        @impl = e
      ensure
        # not really needed since new promises are created rather than reused
        @calculating=false
      end
      raise DynamicError.new "infinite loop was assumed to be non empty, but was empty",nil if expect_non_empty && @impl == []
    end
    raise @impl if DynamicError===@impl
    @impl
  end
  alias by value
end

class By
  def initialize(value,by_value)
    @value=value
    @by_value=by_value
  end
  def by
    @by_value
  end
  def empty
    @value == []
  end
  def value
    @value
  end
end

# Use this to avoid creating promises that are pointless because the value is constant or it will immediately be computed after construction.
class Const < Struct.new(:value)
  def empty
    value==[]
  end
  alias by value
end
class Object
  def const
    Const.new(self)
  end
end

def take(n, a)
  return [] if n < 1 || a.empty
  [a.value[0], Promise.new{ take(n-1, a.value[1]) }]
end

def drop(n, a)
  while n>=1 && !a.empty
    n-=1
    a=a.value[1]
  end
  a.value
end

def range(a,b)
  return [] if a>=b
  [a.const, Promise.new{range(a+1,b)}]
end

def range_from(a)
  [a.const, Promise.new{range_from(a+1)}]
end

# this isn't as lazy as possible, but it gets to use hashes
def occurence_count(a,h=Hash.new(-1))
  return [] if a.empty
  [(h[to_strict_list(a.value[0])]+=1).const, Promise.new{occurence_count(a.value[1], h)}]
end

def filter(a,b,b_elem_type)
  return [] if a.empty || b.empty
  if truthy(b_elem_type,b.value[0])
   [a.value[0],Promise.new{ filter(a.value[1],b.value[1],b_elem_type) }]
  else
    filter(a.value[1],b.value[1],b_elem_type)
  end
end

def sortby(a,b,t)
  sort(toby(a,b),t)
end

def toby(a,b)
  return Null if a.empty || b.empty
  Promise.new{ [By.new(a.value[0].value, b.value[0].value), toby(a.value[1], b.value[1])] }
end

# It would be very interesting and useful to design a more lazy sorting algorithm
# so that you can select ith element in O(n) total time after sorting a list.
def sort(a,t)
  return [] if a.empty
  return a.value if a.value[1].empty
  n=len(a)
  left=take(n/2, a).const
  right=drop(n/2, a).const
  merge(sort(left,t),sort(right,t),t)
end

def merge(a,b,t)
  return b if a==[]
  return a if b==[]
  if spaceship(a[0].by.const, b[0].by.const,t) <= 0
    [a[0], Promise.new{merge(a[1].value,b,t)}]
  else
    [b[0], Promise.new{merge(a,b[1].value,t)}]
  end
end

def to_strict_list(a,sofar=[])
  a=a.value
  return a if !(Array===a)
  return sofar if a==[]
  to_strict_list(a[1],sofar<<to_strict_list(a[0]))
end

def chunk_while(a,b,t)
  return [Null,Null] if a.empty || b.empty
  b0true = Promise.new{ truthy(t,b.value[0])}
  rhs = Promise.new{ chunk_while(a.value[1],b.value[1],t) }
  [
    Promise.new{
      if b0true.value
        [a.value[0], rhs.value[0]]
      else
        []
      end
    },
    Promise.new{
      if b0true.value
        rhs.value[1].value
      else
        [Promise.new{[a.value[0],rhs.value[0]]},rhs.value[1]]
      end
    }
  ]
end

def reverse(a,sofar=[])
  return sofar if a.empty
  reverse(a.value[1],[a.value[0],sofar.const])
end

def reshape(a,b,s=0)
  raise DynamicError.new("empty list given for lengths of reshape", nil) if b.empty
  return [] if a.empty
  [Promise.new{take((b.value[0].value+s).to_i,a)},
   Promise.new{
    c=b.value[0].value+s
    reshape(drop(c.to_i,a).const,b.value[1].empty ? b : b.value[1], c%1)
   }]
end

def join(a,b)
  concat_map(a,Null){|i,r,first|
    first ? append(i,r) : append(b,Promise.new{append(i,r)})
  }
end

def split(a,b) # fyi could be lazier since we know we return a list always
  return [Null,Null] if a.empty
  if (remainder=starts_with(a,b))
    [Null,Promise.new{split(remainder,b)}]
  else
    rhs=Promise.new{split(a.value[1],b)}
    [Promise.new{[a.value[0],Promise.new{rhs.value[0].value}]},Promise.new{rhs.value[1].value}]
  end
end

def starts_with(a,b) # assumed to be strs, returns remainder if match otherwise nil
  return a if b.empty
  return nil if a.empty || a.value[0].value != b.value[0].value
  starts_with(a.value[1],b.value[1])
end

def init(a)
  raise DynamicError.new "init on empty list",nil if a.empty
  return [] if a.value[1].empty
  [a.value[0], Promise.new{ init(a.value[1]) }]
end

# value -> (value -> Promise) -> value
def map(a,&b)
  a.empty ? [] : [Promise.new{b[a.value[0]]}, Promise.new{map(a.value[1],&b)}]
end

# value -> value
# truncate as soon as encounter empty list
def trunc(a)
  a.empty || a.value[0].empty ? [] : [a.value[0], Promise.new{trunc(a.value[1])}]
end

def transpose(a)
  return [] if a.empty
  return transpose(a.value[1]) if a.value[0].empty
  broken = trunc(a.value[1]).const
  hds = Promise.new{ map(broken){|v|v.value[0].value} }
  tls = Promise.new{ map(broken){|v|v.value[1].value} }
  [Promise.new{[a.value[0].value[0],hds]},
   Promise.new{transpose [a.value[0].value[1],tls].const}]
end

def last(a)
  prev=nil
  until a.empty
    prev = a
    a = a.value[1]
  end
  raise DynamicError.new("empty last", nil) if prev == nil
  prev.value[0].value
end

# n = int number of dims to zip
# a = args, [promise]
# f = impl, promises -> value
# returns value
def zipn(n,a,f)
  return f[*a] if n <= 0 || a==[]
  faith = []
  return [] if a.any?{|i|
    begin
      i.empty
    rescue InfiniteLoopError => e
      # gotta have faith
      # solves this type of problem: a=!:,0 +a ::1;2;:3;4
      faith << i
      false # not empty, for now...
    end
  }
  faith.each{|i| i.expect_non_empty = true }
  [Promise.new{zipn(n-1,a.map{|i|Promise.new{i.value[0].value}},f) },
   Promise.new{zipn(n,a.map{|i|Promise.new{i.value[1].value}},f) }]
end

def repeat(a)
  ret = [a]
  ret << Promise.new{ret}
  ret
end

def repn(vec_level,n,a)
  if n<=0
    a
  else
    Promise.new{zipn(vec_level,[a],-> av {
      repeat(repn(0,n-1,av))
    })}
  end
end

def promoten(vec_level,n,a)
  if n<=0
    a
  else
    Promise.new{zipn(vec_level,[a],-> av {
      [promoten(0,n-1,av),Null]
    })}
  end
end

def sum(a)
  return 0 if a.empty
  a.value[0].value+sum(a.value[1])
end

def prod(a)
  return 1 if a.empty
  a.value[0].value*prod(a.value[1])
end

# value -> value -> value
def spaceship(a,b,t)
  if t.dim>0
    return 0 if a.empty && b.empty
    return -1 if a.empty
    return 1 if b.empty
    s0 = spaceship(a.value[0],b.value[0],t-1)
    return s0 if s0 != 0
    return spaceship(a.value[1],b.value[1],t)
  else
    a.value<=>b.value
  end
end

def len(a)
  return 0 if a.empty
  return 1+len(a.value[1])
end

# value -> Promise -> value
def append(v,r)
  v.empty ? r.value : [v.value[0],Promise.new{append(v.value[1], r)}]
end

# promise -> promise -> bool -> (value -> promise -> ... -> value) -> value
def concat_map(v,rhs,first=true,&b)
  if v.empty
    rhs.value
  else
    b[v.value[0],Promise.new{concat_map(v.value[1],rhs,false,&b)},first]
  end
end

def concat(a)
  concat_map(a,Null){|i,r,first|append(i,r)}
end

def inspect_value(t,value,zip_level)
  inspect_value_h(t,value,Null,zip_level)
end

def inspect_value_h(t,value,rhs,zip_level)
  if t==Str && zip_level <= 0
    ['"'.ord.const, Promise.new{
      concat_map(value,Promise.new{str_to_lazy_list('"',rhs)}){|v,r,first|
       str_to_lazy_list(escape_str_char(v.value),r)
      }
    }]
  elsif t==Num
    str_to_lazy_list(value.value.to_s,rhs)
  elsif t==Char
    str_to_lazy_list(inspect_char(value.value),rhs)
  else #List
    [(zip_level>0?"<":"[").ord.const, Promise.new{
      concat_map(value,Promise.new{str_to_lazy_list((zip_level>0?">":"]"),rhs)}){|v,r,first|
        first ?
          inspect_value_h(t-1,v,r,zip_level-1) :
          [','.ord.const,Promise.new{inspect_value_h(t-1,v,r,zip_level-1)}]
      }
    }]
  end
end

# convert a from int to str if tb == str and ta == int, but possibly vectorized
def coerce2s(ta, a, tb)
  return a if ta==tb || tb.is_unknown || ta.is_unknown #??
  case [ta.base_elem,tb.base_elem]
  when [:num,:char]
    raise if ta.dim+1 != tb.dim
    return Promise.new{zipn(ta.dim,[a],->av{str_to_lazy_list(av.value.to_s)})}
  when [:char,:num]
    raise if ta.dim != tb.dim+1
    return a
  else
    raise "coerce of %p %p not supported"%[ta,tb]
  end
end

def to_string(t, value, repl_mode, n, s)
  to_string_h(t,value,t.string_dim, Null, repl_mode, n, s)
end

def to_string_h(t, value, orig_dim, rhs, repl_mode, n, s)
  if t == Num
    inspect_value_h(t, value, rhs, 0)
  elsif t == Char
    [value, rhs]
  else # List
    # print 1d lists on new lines if not in repl mode
    dim = !repl_mode && orig_dim == 1 && t.string_dim == 1 ? 2 : t.string_dim
    # print newline separators after every element for better interactive io
    separator1 = dim == 2 ? n : ""
    # but don't do this for separators like space, you would end up with trailing space in output
    separator2 = ["",s,""][dim] || n

    concat_map(value,rhs){|v,r,first|
      svalue = Promise.new{ to_string_h(t-1, v, orig_dim, Promise.new{str_to_lazy_list(separator1, r)}, repl_mode, n, s) }
      first ? svalue.value : str_to_lazy_list(separator2, svalue)
    }
  end
end

def to_char(i)
  begin
    "%c" % i
  rescue ArgumentError
    raise DynamicError.new "invalid character with ord value: %d" % i, nil
  end
end

def print_string(value,n)
  nord = n.ord
  while !value.empty
    c = value.value[0].value
    $last_was_newline = c == nord
    print to_char(c)
    value = value.value[1]
  end
end

def is_digit(i)
  i>=48 && i<58
end

def read_num(s)
  multiplier=1
  until s.empty || is_digit(s.value[0].value)
    if s.value[0].value == ?-.ord
      multiplier *= -1
    else
      multiplier = 1
    end
    s = s.value[1]
  end
  v = 0
  found_int = false
  until s.empty || !is_digit(s.value[0].value)
    found_int = true
    v = v*10+s.value[0].value-48
    s = s.value[1]
  end

  # find decimal pointer and numbers after
  if found_int && !s.empty && s.value[0].value == ?..ord && !s.value[1].empty && is_digit(s.value[1].value[0].value)
    decimals = "0."
    s = s.value[1]
    until s.empty || !is_digit(s.value[0].value)
      found_int = true
      decimals << s.value[0].value.chr
      s = s.value[1]
    end
    v += decimals.to_f
  end

  [multiplier * v, found_int, s]
end

# string value -> [string] value
def lines(s)
  return [] if s.empty

  after = Promise.new{lines(s.value[1])}
  if s.value[0].value == 10
    [Null, after]
  else
    [Promise.new{
      after.empty ? [s.value[0], Null] : [s.value[0], after.value[0]]
     },
     Promise.new{
      after.empty ? [] : after.value[1].value
     }]
   end
end

# string promise -> [int] value
def split_non_digits(s)
  return [] if s.empty
  v,found,s2=read_num(s)
  return [] if !found
  [v.const,Promise.new{split_non_digits(s2)}]
end

ReadStdin = Promise.new{ read_stdin }
def read_stdin
  c=STDIN.getc
  if c.nil?
    []
  else
    [c.ord.const, Promise.new{ read_stdin }]
  end
end

Null = [].const

def str_to_lazy_list(s,rhs=Null)
  to_lazy_list(s.chars.map(&:ord), rhs)
end

def to_lazy_list(l, rhs=Null, ind=0)
  ind >= l.size ? rhs.value : [l[ind].const, Promise.new{to_lazy_list(l, rhs, ind+1)}]
end

def to_eager_list(v)
  x=[]
  until v.empty
    x<<v.value[0].value
    v=v.value[1]
  end
  x
end

def to_eager_str(v)
  to_eager_list(v).map{|i|to_char i}.join
end

def truthy(type, value)
  begin
    if type == Num
      value.value > 0
    elsif type == Char
      !!to_char(value.value)[/\S/]
    else # List
      !value.empty
    end
  rescue AtlasError => e # dynamic and inf loop
    return false
  end
end
