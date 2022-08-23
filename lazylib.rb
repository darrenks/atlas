require_relative "./escape.rb"
require_relative "./error.rb"

$reductions = 0

def run(root,output_limit=10000,out=STDOUT)
  $out = out
  $limit = output_limit
  root.impl.value
  #trace(root).value
end

class Promise
  def initialize(&block)
    @impl=block
    @calculating=false
  end
  def value
    if Proc===@impl
      raise InfiniteLoopError.new "infinite loop detected",nil if @calculating # todo fix from location
      @calculating=true
      $reductions+=1
      @impl=@impl[]
    end
    @impl
  end
  def inspect
    "promise"
  end
end

def limprint(s)
  s = s.to_s
  char_count = [$limit,s.size].min
  $out.print s[0,char_count]
  $limit -= char_count
  $limit <= 0
end

def take(n, a)
  return [] if n <= 0 || a.value == []
  [a.value[0], Promise.new{ take(n-1, a.value[1]) }]
end

def drop(n, a)
  while n>0 || a.value == []
    n-=1
    a=a.value[1]
  end
  a.value
end

def init(a,from)
  raise DynamicError.new "init on empty list",from if a==[]
  return [] if a[1].value == []
  [a[0], Promise.new{ init(a[1].value,from) }]
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

def last(a,from)
  prev=nil
  until a.empty?
    prev = a
    a = a[1].value
  end
  raise DynamicError.new("empty last", from) if prev == nil
  prev[0].value
end

# n = int number of dims to zip
# a = args, [promise]
# f = impl, promises -> value
# returns value
def zipn(n,a,f)
  return f[*a] if n <= 0 || a==[]
#   return [] if !a.empty? && a[0].value==[]
  return [] if a.any?{|i|
    begin
      i.value==[]
    rescue InfiniteLoopError
      # gotta have faith
      # solves this type of problem:   !] a=!:,0 +a !~!I
      false
    end
  }
#   [Promise.new{ zipn(n-1,a.map{|i|i.value[0]},f) },
#    Promise.new{ zipn(n,a.map{|i|i.value[1]},f) }]
 [ZipPromise.new(n-1,a,f,0), ZipPromise.new(n,a,f,1)]
end

class ZipPromise
  def initialize(n,a,f,x)
    @n=n; @a=a; @f=f; @x=x
    @calculating=false
  end
  def value
    return @memo if @memo
    raise InfiniteLoopError.new "infinite loop detected",nil if @calculating
    @calculating=true
    $reductions+=1
    a=@a.map{|i|i.value[@x]}
    @memo = zipn(@n,a,@f)
  end
end

def repn(n,v)
  n <= 0 ? v : Promise.new { repeat(repn(n-1,v)) }
end

def repeat(a)
  ret = [a]
  ret << Promise.new{ret}
  ret
end

# value -> value -> value
def equal(a,b,t)
  if t.dim>0
    return true if a==[] && b==[]
    return false if a==[] || b==[]
    return equal(a[0].value,b[0].value,t.elem) && equal(a[1].value,b[1].value,t)
  else
    a==b
  end
end

# value -> Promise -> value
def append(v,r)
  v==[] ? r.value : [v[0],Promise.new{append(v[1].value, r)}]
  #concat_map(v,r){|v2,r2|[Promise.new{v2},r2]}
end

# value -> value -> bool -> (value -> promise -> ... -> value) -> value
def concat_map(v,rhs,first=true,&b)
  if v==[]
    rhs
  else
    b[v[0].value,Promise.new{concat_map(v[1].value,rhs,false,&b)},first]
  end
end

def inspect_value(t,value)
  inspect_value_h(t,value,Null)
end

def inspect_value_h(t,value,rhs)
  if t==Str
    [Promise.new{'"'.ord}, Promise.new{
      concat_map(value,str_to_lazy_list('"',rhs)){|v,r,first|
       str_to_lazy_list(escape_str_char(v),r)
      }
    }]
  elsif t==Int
    str_to_lazy_list(value.to_s,rhs)
  elsif t==Char
    str_to_lazy_list(inspect_char(value),rhs)
  else #Array
    [Promise.new{"[".ord}, Promise.new{
      concat_map(value,str_to_lazy_list("]",rhs)){|v,r,first|
        first ?
          inspect_value_h(t.elem,v,r) :
          [Promise.new{','.ord},Promise.new{inspect_value_h(t.elem,v,r)}]
      }
    }]
  end
end

def print_value(t,value,orig_t)
  if t==Int
    limprint value
  elsif t==Char
    limprint "%c" % value
  else #Array
    first = true
    orig_dim = orig_t.dim+(t.is_char ? -1:0)
    dim = t.dim+(t.is_char ? -1:0)
    separator = [""," ","\n"][dim] || "\n\n"
    separator = "\n" if orig_dim == 1 && dim == 1
    while value != []
      return if limprint separator unless first
      first = false
      print_value(t.elem,value[0].value,orig_t)
      return if $limit <= 0
      value = value[1].value
    end
  end
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

Null = Promise.new{ [] }

def str_to_lazy_list(s,rhs=Null)
  to_lazy_list(s.chars.map(&:ord), rhs)
end

def to_lazy_list(l, rhs=Null, ind=0)
  ind >= l.size ? rhs.value : [Promise.new{l[ind]}, Promise.new{to_lazy_list(l, rhs, ind+1)}]
end