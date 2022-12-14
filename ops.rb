require_relative "./type.rb"
require_relative "./escape.rb"
require_relative "./error.rb"
require_relative "./lazylib.rb"
require_relative "./spec.rb"

NO_PROMOTE = :a_no         #
ALLOW_PROMOTE = :b_allow   # promote if only way to satisfy type spec
PREFER_PROMOTE = :c_prefer # promote instead of replicate
MUST_PROMOTE = :d_must     # there must always be at least 1 promotion

class Op < Struct.new(
    :name,
    :sym, # optional
    :type,
    :min_zip_level,
    :promote,
    :impl)
  def narg
    type ? type[0].specs.size : 0
  end
  def str
    token.str
  end
end

def create_op(
  name: ,
  sym: nil,
  type: ,
  min_zip_level: 0,
  promote: ALLOW_PROMOTE,
  poly_impl: nil, # impl that needs type info
  impl: nil,
  impl_with_loc: nil # impl that could throw, needs token location for err msgs
)
  type = create_specs(type)
  raise "exactly on of [poly_impl,impl,impl_with_loc] must be set" if [poly_impl,impl,impl_with_loc].compact.size != 1
  if poly_impl
    built_impl = -> arg_types,from { poly_impl[*arg_types] }
  elsif impl_with_loc
    built_impl = -> arg_types,from { impl_with_loc[from] }
  else
    built_impl = -> arg_types,from { Proc===impl ? impl : lambda { impl } }
  end
  Op.new(name,sym,type,min_zip_level,promote,built_impl)
end

OpsList = [
  create_op(
    name: "cons",
    sym: ":",
    # Example: 'a:"bc" -> "abc"
    # Test: 1:$ -> [1]
    # todo
    ## Test: :$ $ -> [1]
    type: { [A,[A]] => [A] },
    impl: -> a,b { [a,b] },
  ),
  create_op(
    name: "head",
    sym: "[",
    # Example: ["abc" -> 'a
    type: { [A] => A },
    impl_with_loc: -> from { -> a {
      raise DynamicError.new "head on empty list",from if a.value==[]
      a.value[0].value
    }},
    promote: NO_PROMOTE,
  ), create_op(
    name: "last",
    sym: "]",
    promote: NO_PROMOTE,
    # Example: ]"abc" -> 'c
    type: { [A] => A },
    impl_with_loc: -> from { -> a {
      raise DynamicError.new "last on empty list",from if a.value==[]
      last(a.value)
    }}
  ), create_op(
    name: "tail",
    # Example: tail "abc" -> "bc"
    sym: ">",
    promote: NO_PROMOTE,
    type: { [A] => [A] },
    impl_with_loc: -> from { -> a {
      raise DynamicError.new "tail on empty list",from if a.value==[]
      a.value[1].value}}
  ), create_op(
    name: "init",
    # Example: init "abc" -> "ab"
    sym: "<",
    promote: NO_PROMOTE,
    type: { [A] => [A] },
    impl_with_loc: -> from { -> a {
      raise DynamicError.new "init on empty list",from if a.value==[]
      init(a.value)
    }}
  ), create_op(
    name: "add",
    sym: "+",
    # Example: 1+2 -> 3
    type: { [Int,Int] => Int,
            [Int,Char] => Char,
            [Char,Int] => Char },
    impl: -> a,b { a.value + b.value }
  ), create_op(
    name: "sub",
    sym: "-",
    # Example: 5-3 -> 2
    type: { [Int,Int] => Int,
            [Char,Int] => Char,
            [Char,Char] => Int },
    impl: -> a,b { a.value - b.value }
  ), create_op(
    name: "mult",
    # Example: 2*3 -> 6
    sym: "*",
    type: { [Int,Int] => Int },
    impl: -> a,b { a.value * b.value }
  ), create_op(
    name: "div",
    # Example: 7/3 -> 2
    sym: "/",
    type: { [Int,Int] => Int },
    impl_with_loc: -> from { -> a,b {
      if b.value==0
        raise DynamicError.new("div 0", from) # todo maybe too complicated to be worth it same for mod
      else
        a.value/b.value
      end
    }}
  ), create_op(
    name: "mod",
    # Example: 7%3 -> 1
    sym: "%",
    type: { [Int,Int] => Int },
    impl_with_loc: -> from { -> a,b {
      if b.value==0
        raise DynamicError.new("mod 0",from)
      else
        a.value % b.value
      end
    }}
  ), create_op(
    name: "neg",
    sym: "~",
    type: { Int => Int,
            Str => Int },
    poly_impl: -> t {
      case t
      when Int
        # Example: ~2 -> -2
        -> a { -a.value }
      when Str
        # Example: ~"12" -> 12
        # Test: ~"a12b" -> 12
        # Test: ~"12 34" -> 12
        # Test: ~"-12" -> -12
        # Test: ~"--12" -> 12
        -> a { read_int(a.value)[0] }
      else
        raise
      end
    }
  ), create_op(
    name: "rep",
    sym: ",",
    # Example: ,2 -> [2,2,2,2,2...
    type: { A => [A] },
    impl: -> a { repeat(a) }
  ), create_op(
    name: "eq",
    # Example: 3==3 -> [3]
    # Test: 3==2 -> []
    sym: "==",
    type: { [A,A] => [A] },
    poly_impl: -> ta,tb {-> a,b { equal(a.value,b.value,ta) ? [a,Null] : [] } }
  ), create_op(
    name: "len",
    # Example: # "asdf" -> 4
    sym: "#",
    promote: NO_PROMOTE,
    type: { [A] => Int },
    impl: -> a { len(a.value) }
  ), create_op(
    name: "nil",
    # Example: $ -> []
    sym: "$",
    type: Nil,
    impl: -> { [] }
  ), create_op(
    name: "pad",
    # Example: "abc"|'_ -> "abc_____...
    sym: "|",
    type: { [[A],A] => [A] },
    impl: -> a,b { pad(a,b) }
  ), create_op(
    name: "const",
    sym: "&",
    # Example: "abcd"&"123" -> "abc"
    type: { [A,B] => A },
    min_zip_level: 1,
    impl: -> a,b { a.value }
  ), create_op(
    name: "if",
    sym: "?",
    # Example: if 1 then "yes" else "no" -> "yes"
    type: { [A,B,B] => B },
    poly_impl: -> ta,tb,tc {
      if ta == Int
        # Test: !if (~1):;2 then 1 else 0 -> [0,1]
        lambda{|a,b,c| a.value > 0 ? b.value : c.value }
      elsif ta == Char
        # Test: !if " d" then 1 else 0 -> [0,1]
        lambda{|a,b,c| a.value.chr[/\S/] ? b.value : c.value }
      else # List
        # Test: !if "":;"a" then 1 else 0 -> [0,1]
        lambda{|a,b,c| a.value != [] ? b.value : c.value }
      end
    }
  ), create_op(
    # Hidden
    name: "input",
    sym: "I",
    type: Str,
    impl: -> { ReadStdin.value }
  ), create_op(
    # Hidden
    name: "input2",
    sym: "zI",
    type: [Str],
    impl: -> { lines(ReadStdin.value) }
  ), create_op(
    # Hidden
    name: "tostring",
    # Example: tostring 12 -> "12"
    type: { A => Str },
    # Test: tostring "a" -> "a"
    # Test: tostring 'a -> "a"
    # Test: tostring 2:;1 -> "2 1"
    # Test: tostring (2:;1):;(3:;4) -> "2 1\n3 4"
    poly_impl: -> t { -> a { to_string(t,a.value) } }
  ), create_op(
    name: "show",
    sym: "`",
    # Example: `12 -> "12"
    type: { A => Str },
    # Test: `"a" -> "\"a\""
    # Test: `'a -> "'a"
    # Test: `;1 -> "[1]"
    poly_impl: -> t { -> a { inspect_value(t,a.value) } }
  ), create_op(
    name: "single",
    sym: ";",
    # Example: ;2 -> [2]
    type: { A => [A] },
    impl: -> a { [a,Null] }
  ), create_op(
    name: "take",
    sym: "[",
    # Example: 3["abcd" -> "abc"
    # Test: (~2)["abc" -> ""
    # Test: 2["" -> ""
    type: { [Int,[A]] => [A] },
    impl: -> a,b { take(a.value, b) }
  ), create_op(
    name: "drop",
    sym: "]",
    # Example: 3]"abcd" -> "d"
    # Test: (~2)]"abc" -> "abc"
    # Test: 2]"" -> ""
    type: { [Int,[A]] => [A] },
    impl: -> a,b { drop(a.value, b) }
  ), create_op(
    name: "concat",
    sym: "_",
    # Example: _"abc":;"123" -> "abc123"
    type: { [[A]] => [A] },
    impl: -> a { concat_map(a.value,[]){|i,r,first|append(i,r)} },
  ), create_op(
    name: "append",
    sym: "@",
    # Example: "abc"@"123" -> "abc123"
    type: { [[A],[A]] => [A] },
    impl: -> a,b { append(a.value,b) },
  ), create_op(
    name: "implicit_promote_and_append",
    # Example: "abc" "123" -> ["abc","123"]
    # Example: 1 2 3 -> [1,2,3]
    # Test: 'a "123" -> "a123"
    # Test: "123" 'a -> "123a"
    sym: " ", # although you don't need a space with parens/etc.
    type: { [[A],[A]] => [A] },
    impl: -> a,b { append(a.value,b) },
    promote: MUST_PROMOTE,
  ), create_op(
    name: "transpose",
    sym: "\\",
    # Example: \"abc":;"123" -> ["a1","b2","c3"]
    # Test: \"abc":;"1234" -> ["a1","b2","c3","4"]
    type: { [[A]] => [[A]] },
    impl: -> a { transpose(a.value) },
  )
]

Ops1 = {}
Ops2 = {}
AllOps = {}
OpsList.each{|op|
  ops = case op.narg
  when 0
    Ops1[op.name] = Ops1[op.sym] = op
    Ops2[op.name] = Ops2[op.sym] = op
  when 1
    Ops1[op.name] = Ops1[op.sym] = op
  when 2
    Ops2[op.name] = Ops2[op.sym] = op
  when 3 # if
    Ops1[op.name] = op
    Ops2[op.sym] = op
  else; error; end
  AllOps[op.name] = AllOps[op.sym] = op
}
RepOp = AllOps["rep"]
PromoteOp = AllOps["single"]
NilOp = AllOps['nil']

def create_int(str)
  create_op(
    sym: str,
    name: str,
    type: Int,
    impl: str.to_i
  )
end

def create_str(str)
  raise LexError.new("unterminated string") if str[-1] != '"'
  create_op(
    sym: str,
    name: str,
    type: Str,
    impl: str_to_lazy_list(parse_str(str[1...-1]))
  )
end

def create_char(str)
  raise LexError.new("empty char") if str.size < 2
  create_op(
    sym: str,
    name: str,
    type: Char,
    impl: parse_char(str[1..-1]).ord
  )
end
