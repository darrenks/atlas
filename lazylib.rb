# Set this to default because these get used a bit during parse (e.g. creating a string)
$step_limit=Float::INFINITY
$reductions = 0

def run(root,out=STDOUT,output_limit=10000,step_limit=Float::INFINITY)
  $step_limit = step_limit + $reductions
  print_string(make_promises(root), out, output_limit)
end

def make_promises(node)
  return node.promise if node.promise
  arg_types = node.replicated_args.map{|arg|arg.type-node.zip_level}
  args = nil
  node.promise = Promise.new {
    zipn(node.zip_level, args, node.op.impl[arg_types, node])
  }
  args = node.replicated_args.map{|arg| make_promises(arg) }
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
  def inspect
    "promise"
  end
end

def take(n, a)
  return [] if n <= 0 || a.empty
  [a.value[0], Promise.new{ take(n-1, a.value[1]) }]
end

def drop(n, a)
  while n>0 && !a.empty
    n-=1
    a=a.value[1]
  end
  a.value
end

def init(a)
  raise DynamicError.new "init on empty list",nil if a.empty
  return [] if a.value[1].empty
  [a.value[0], Promise.new{ init(a.value[1]) }]
end

# value -> (value -> Promise) -> value
def map(a,&b)
  a.empty ? [] : [b[a.value[0]], Promise.new{map(a.value[1],&b)}]
end

# value -> value
# truncate as soon as encounter empty list
def trunc(a)
  a.empty || a.value[0].empty ? [] : [a.value[0], Promise.new{trunc(a.value[1])}]
end

def transpose(a)
  return [] if a.empty
  return transpose(a.value[1]) if a.value[0].empty
  broken = Promise.new{ trunc(a.value[1]) }
  hds = Promise.new{ map(broken){|v|v.value[0]} }
  tls = Promise.new{ map(broken){|v|v.value[1]} }
  [Promise.new{[a.value[0].value[0],hds]},
   Promise.new{transpose Promise.new{[a.value[0].value[1],tls]}}]
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

def repeat(a)
  ret = [a]
  ret << Promise.new{ret}
  ret
end

def pad(a,b)
  [
    Promise.new{ a.empty ? b.value : a.value[0].value },
    Promise.new{ pad( Promise.new{ a.empty ? [] : a.value[1].value }, b) }
  ]
end

# value -> value -> value
def equal(a,b,t)
  if t.dim>0
    return true if a.empty && b.empty
    return false if a.empty || b.empty
    return equal(a.value[0],b.value[0],t-1) && equal(a.value[1],b.value[1],t)
  else
    a.value==b.value
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

def inspect_value(t,value)
  inspect_value_h(t,value,Null)
end

def inspect_value_h(t,value,rhs)
  if t == Nil
    str_to_lazy_list("[]",rhs)
  elsif t==Str
    [Promise.new{'"'.ord}, Promise.new{
      concat_map(value,Promise.new{str_to_lazy_list('"',rhs)}){|v,r,first|
       str_to_lazy_list(escape_str_char(v.value),r)
      }
    }]
  elsif t==Int
    str_to_lazy_list(value.value.to_s,rhs)
  elsif t==Char
    str_to_lazy_list(inspect_char(value.value),rhs)
  else #List
    [Promise.new{"[".ord}, Promise.new{
      concat_map(value,Promise.new{str_to_lazy_list("]",rhs)}){|v,r,first|
        first ?
          inspect_value_h(t-1,v,r) :
          [Promise.new{','.ord},Promise.new{inspect_value_h(t-1,v,r)}]
      }
    }]
  end
end

def to_string(t, value)
  to_string_h(t,value,t.string_dim, Null)
end

def to_string_h(t, value, orig_dim, rhs)
  if t == Int
    inspect_value_h(t, value, rhs)
  elsif t == Char
    [Promise.new{value.value}, rhs]
  else # List
    dim = t.string_dim
    # print newline separators after every element for better interactive io
    separator1 = dim == 2 ? "\n" : ""
    # but don't do this for separators like space, you would end up with trailing space in output
    separator2 = [""," ",""][dim] || "\n"

    # this would make the lang a bit better on golf.shinh.org but not intuitive
    #separator = "\n" if orig_dim == 1 && dim == 1

    concat_map(value,rhs){|v,r,first|
      svalue = Promise.new{ to_string_h(t-1, v, orig_dim, Promise.new{str_to_lazy_list(separator1, r)}) }
      first ? svalue.value : str_to_lazy_list(separator2, svalue)
    }
  end
end

def print_string(value, out, limit)
  begin
    while !value.empty && limit > 0
      out.print "%c" % value.value[0].value
      value = value.value[1]
      limit -= 1
    end
  rescue ArgumentError
    raise DynamicError.new "invalid character for printing ordinal value: %d" % value.value[0].value, nil
  end
end

def read_int(s)
  multiplier=1
  until s.empty || s.value[0].value.chr =~ /[0-9]/
    if s.value[0].value == ?-.ord
      multiplier *= -1
    else
      multiplier = 1
    end
    s = s.value[1]
  end
  v = 0
  found_int = false
  until s.empty || !(s.value[0].value.chr =~ /[0-9]/)
    found_int = true
    v = v*10+s.value[0].value-48
    s = s.value[1]
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

def truthy(type, value)
  if type == Int
    value.value > 0
  elsif type == Char
    !!value.value.chr[/\S/]
  else # List
    !value.empty
  end
end
