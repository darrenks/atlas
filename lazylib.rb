require_relative "./escape.rb"
require_relative "./error.rb"

$reductions = 0

def run(root,output_limit=10000,out=STDOUT)
  $out = out
  $limit = output_limit
  make_promises(root)
  root.promise.value
  #trace(root).value
end

def make_promises(node)
  return node.promise if node.promise
  arg_types = node.args.map{|arg|arg.type-node.zip_level}
  args = nil
  node.promise = Promise.new {
    zipn(node.zip_level, args, node.op.get_impl(arg_types))
  }
  args = node.args.map{|arg| make_promises(arg) }
  node.promise
end

class Promise
  attr_accessor :expect_non_empty
  def initialize(&block)
    @impl=block
  end
  def value
    if Proc===@impl
      raise InfiniteLoopError.new "infinite loop detected",self,nil if @calculating # todo fix from location
      @calculating=true
      $reductions+=1
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
  while n>0 && a.value != []
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

def repn(n,v)
  n <= 0 ? v : Promise.new { repeat(repn(n-1,v)) }
end

def repeat(a)
  ret = [a]
  ret << Promise.new{ret}
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
  if t == Nil
    str_to_lazy_list("[]",rhs)
  elsif t==Str
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
    orig_dim = orig_t.string_dim
    dim = t.string_dim
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

def atlas_catch(a)
  begin
    return [] if a.value == []
    a.value[0].value
    [a.value[0], Promise.new{ atlas_catch(a.value[1]) }]
  rescue DynamicError
    []
  end
end