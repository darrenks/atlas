require_relative "./type.rb"
require_relative "./escape.rb"
require_relative "./error.rb"

Op=Struct.new(
  :alias,
  :n_arg,
  :n_ret,
  :behavior,
  :token)
class Op
  def str
    token.str
  end
end

#
#   :impl, # curried fn to return impl based on arg types
#   :type, # fn to determine return type
#   :static, # returns [[min dims],allowed zip level,auto zip level]
#   :type_checker, # optional post pass function for type validity

alias lazy lambda
def eager
  lambda{|*args|yield(*args.map{|a|a.value})}
end
def ut_eager # untyped eager
  lambda{|*_|lambda{|*args|yield(*args.map{|a|a.value})}}
end
def ut_lazy(&b)
  lambda{|*_|b}
end
Inf = 1000 # for max zip level

def create_op(alias_,n_arg,n_ret,impl,type,static,type_checker=nil)
  Op.new(alias_,n_arg,n_ret,lambda{|from|[impl,type,static,type_checker]})
end

def scalar_bin_op(alias_,type_table,&block)
  Op.new(alias_,2,1,lambda{|from|[
    ut_eager(&block[from]),
    eager{|a,b|
      ret = type_table[      [[false,false],[false,true],[true,false],[true,true]].index([a.is_char,b.is_char])]
      raise AtlasTypeError.new"type error in scalar_bin_op, todo improve msg",from if ret.nil?
      ret
    },
    eager{|a,b| [[0,0],0,[a,b].max] }]})
end

Ops = {
  "+" => scalar_bin_op("add",[Int,Char,Char,nil]){|from|lambda{|a,b|a+b}},
  "*" => scalar_bin_op("mult",[Int,nil,nil,nil]){|from|lambda{|a,b|a*b}},
  "-" => scalar_bin_op("sub",[Int,nil,Char,Int]){|from|lambda{|a,b|a-b}},
  "/" => scalar_bin_op("div",[Int,nil,nil,nil]){|from|lambda{|a,b|if b==0
    raise DynamicError.new("div 0",from)
  else
    a/b
  end}},
  "%" => scalar_bin_op("mod",[Int,nil,Int,nil]){|from|lambda{|a,b|b==0?0:a%b}},
  "~" => create_op("neg",1,1,
    eager{|t| t.is_char ?
      eager{|a| read_int(a)[0] } :
      eager{|a| -a }},
    eager{|a| Int },
    eager{|a| a.is_char ? [[1],0,a-1] : [[0],0,a] }),  "!~" => Op.new("!read",1,1,lambda{|from|[
    ut_eager{|a| split_non_digits(a) },
    eager{|a| raise AtlasTypeError.new "!~ only on strs",from if !a.is_char; Int.list_of },
    eager{|a| [[1],0,a-1] }]}),
  "$" => create_op("nil",0,1,
    ut_eager{ [] },
    lambda{ Int.list_of },
    lambda{ [[],Inf,0] }),
  "\"" => create_op("string",0,1, # only used with z" (no matching " needed)
    ut_eager{ [] },
    lambda{ Str },
    lambda{ [[],Inf,0] }),
  # cons (todo vec)
  ":" => Op.new("cons",2,1,lambda{|from|[
    ut_lazy{|a,b| [a,b] },
    lazy{|a,b| a.value.list_of },
    lazy{|a,b| #err maybe;
      [[0,0],a.value,0] },
    lambda{|a,b|raise AtlasTypeError.new("cons dims type mismatch %p %p" % [a, b],from) if a+1 != b}]} ), #todo relax when better type inference for circular programs (need to know resulting dim right away)
  ")" => Op.new("tail",1,1,lambda{|from|[
    ut_eager{|a|
      raise DynamicError.new "tail empty list",from if a==[]
      a[1].value },
    eager{|a| a },
    eager{|a| [[1],a-1,0] }]}),
  "[" => Op.new("head",1,1,lambda{|from|[
    ut_eager{|a|
      raise DynamicError.new "head empty list",from if a==[]
      a[0].value },
    eager{|a| a.elem },
    eager{|a| [[1],a-1,0] }]}),
  "]" => Op.new("last",1,1,lambda{|from|[
    ut_eager{|a| last(a,from) },
    eager{|a| a.elem },
    eager{|a| [[1],a-1,0] }]}),
  "?" => Op.new("if",3,1,lambda{|from|[
    eager{|ta,tb,tc|
      if ta == Int
        lazy{|a,b,c| a.value > 0 ? b.value : c.value }
      elsif ta == Char
        lazy{|a,b,c| a.value.chr[/\S/] ? b.value : c.value }
      else # List
        lazy{|a,b,c| a.value != [] ? b.value : c.value }
      end
    },
    eager{|a,b,c| raise AtlasTypeError.new "trinary 2nd and 3rd types must be equal",from if b != c; b },
    eager{|a,b,c| [[0,c-b,b-c],a,0] }]}),

  "{" => create_op("take",2,1,
    ut_lazy{|a,b| take(a.value, b) },
    eager{|a,b| b},
    eager{|a,b| [[0,1],b-1,a] }),

  "}" => create_op("drop",2,1,
    ut_lazy{|a,b| drop(a.value, b) },
    eager{|a,b| b},
    eager{|a,b| [[0,1],b-1,a] }),
  "(" => Op.new("init",1,1,lambda{|from|[
    ut_eager{|a| init(a,from) },
    eager{|a| a },
    eager{|a| [[1],a-1,0] }]}),

  "=" => Op.new("eq",2,1,lambda{|from|[
    eager{|ta,tb|eager{|a,b| equal(a,b,ta) ? 1 : 0 }},
    lazy{|a,b| Int },
    eager{|a,b| [[0,0],[a,b].min,(a-b).abs] },
    lambda{|a,b| raise AtlasTypeError.new("equality type mismatch %p %p" % [a, b],from) if a.is_char != b.is_char}]} ),

  "@" => Op.new("append",2,1,lambda{|from|[
    ut_lazy{|a,b| append(a.value,b) },
    lazy{|a,b| a.value },
    eager{|a,b| [[1,1],a-1,0] },
    lambda{|a,b| raise AtlasTypeError.new("append type mismatch %p %p" % [a, b],from) if a != b}]} ), #todo relax when better type

  "_" => create_op("concat",1,1,
    ut_eager{|a| concat_map(a,[]){|i,r,first|append(i,r)} },
    eager{|a| a.elem},
    eager{|a| [[2],a-2,0] }),

  "," => create_op("repeat",1,1,
    ut_lazy{|a| repeat(a) },
    eager{|a| a.list_of },
    eager{|a| [[0],a,0] }),

  ";" => create_op("single",1,1,
    ut_lazy{|a| [a,Null] },
    eager{|a| a.list_of },
    eager{|a| [[0],a,0] }),

  # todo make it so that !\ :"abc" :"123" !" acts like  !\ !; :"abc" :"123" !"
  "\\" => create_op("transpose",1,1,
    ut_eager{|a| transpose(a) },
    eager{|a| a },
    eager{|a| [[2],a-2,0] }),


  "`" => create_op("show",1,1,
    eager{|t|eager{|a| inspect_value(t,a) }},
    eager{|a| Str },
    eager{|a| [[0],a,0] }),

  "O" => create_op("output",1,0,
    eager{|t|eager{|a| print_value(t,a,t) }},
    eager{|a| Str }, # lies, its null
    eager{|a| [[0],0,0] }), # todo later deduce spot, maybe unassigned things or topleft
 "I" => create_op("input",0,1,
    ut_eager{ ReadStdin.value },
    lambda{ Str },
    lambda{ [[],0,0] }),
 "!I" => create_op("!input",0,1,
    ut_eager{ lines(ReadStdin.value) },
    lambda{ Str.list_of },
    lambda{ [[],0,0] }),
}

Ops2d = {
  " " => Op.new("space",0,0),
  "^" => Op.new("up",1,1),
  "<" => Op.new("left",1,1),
  "v" => Op.new("down",1,1),
  ">" => Op.new("right",1,1),
  "." => Op.new("dup",1,2),
  "#" => Op.new("cross",2,2),
}

SpecialZips = Ops.keys.select{|o|o=~/^!/}
def is_special_zip(str)
  SpecialZips.include?(str) || SpecialZips.any?{|o|Ops[o].alias == str}
end

def create_int(str)
  create_op("int",0,1,
    ut_eager{str.to_i},
    lambda{Int},
    lambda{[[],0,0]}) # todo could zip these for coolness
end

def create_str(str)
  str_parsed = parse_str(str[1...-1])
  create_op("str",0,1,
    ut_eager{str_to_lazy_list(str_parsed)},
    lambda{Str},
    lambda{[[],0,0]})
end

def create_char(str)
  char_parsed = parse_char(str[1..-1]).ord
  create_op("char",0,1,
    ut_eager{char_parsed},
    lambda{Char},
    lambda{[[],0,0]})
end