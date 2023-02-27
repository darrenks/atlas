require_relative "./type.rb"
require_relative "./spec.rb"

MacroImpl = -> *args { raise "macro impl called" }

class Op < Struct.new(
    :name,
    :sym, # optional
    :type,
    :min_zip_level, # only const uses it, todo remove probably
    :no_zip,
    :impl)
  def narg
    type ? type[0].specs.size : 0
  end
end

def create_op(
  name: ,
  sym: nil,
  type: ,
  min_zip_level: 0,
  no_zip: false,
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
  Op.new(name,sym,type,min_zip_level,no_zip,built_impl)
end

def int_col(n)
  -> {
    map(lines(ReadStdin).const){|v|
      take(1,Promise.new{drop(n,Promise.new{split_non_digits(v)})})
    }
  }
end

OpsList = [
  create_op(
    name: "head",
    sym: "[",
    # Example: "abc"[ -> 'a
    type: { [A] => A },
    impl_with_loc: -> from { -> a {
      raise DynamicError.new "head on empty list",from if a.empty
      a.value[0].value
    }},
  ), create_op(
    name: "last",
    sym: "]",
    # Example: "abc"] -> 'c
    type: { [A] => A },
    impl_with_loc: -> from { -> a {
      raise DynamicError.new "last on empty list",from if a.empty
      last(a)
    }}
  ), create_op(
    name: "tail",
    # Example: "abc" tail -> "bc"
    sym: ">",
    type: { [A] => [A] },
    impl_with_loc: -> from { -> a {
      raise DynamicError.new "tail on empty list",from if a.empty
      a.value[1].value}}
  ), create_op(
    name: "init",
    # Example: "abc" init -> "ab"
    sym: "<",
    type: { [A] => [A] },
    impl_with_loc: -> from { -> a {
      raise DynamicError.new "init on empty list",from if a.empty
      init(a)
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
            Str => [Int] },
    poly_impl: -> t {
      case t
      when Int
        # Example: 2~ -> -2
        -> a { -a.value }
      when Str
        # Example: "1 2 -3 4a5 - -6 --7" ~ -> [1,2,-3,4,5,-6,7]
        -> a { split_non_digits(a) }
      else
        raise
      end
    }
  ), create_op(
    name: "rep",
    sym: ",",
    # Example: 2, -> <2,2,2,2,2...
    type: { A => VecOf.new(A) },
    impl: -> a { repeat(a) }
  ), create_op(
    name: "eq",
    # Example: 3=3 -> [3]
    # Test: 3=2 -> []
    sym: "=",
    type: { [A,A] => [A] },
    poly_impl: -> ta,tb {-> a,b { spaceship(a,b,ta) == 0 ? [b,Null] : [] } }
  ), create_op(
    name: "lessThan",
    # Example: 4<5 -> [5]
    # Test: 5<4 -> []
    sym: "<",
    type: { [A,A] => [A] },
    poly_impl: -> ta,tb {-> a,b { spaceship(a,b,ta) == -1 ? [b,Null] : [] } }
  ), create_op(
    name: "greaterThan",
    # Example: 5>4 -> [4]
    # Test: 4>5 -> []
    sym: ">",
    type: { [A,A] => [A] },
    poly_impl: -> ta,tb {-> a,b { spaceship(a,b,ta) == 1 ? [b,Null] : [] } }
  ), create_op(
    name: "len",
    # Example: "asdf"# -> 4
    sym: "#",
    type: { [A] => Int },
    impl: -> a { len(a) }
  ), create_op(
    name: "nil",
    # Example: nil -> []
    type: Nil,
    impl: -> { [] }
  ), create_op(
    name: "const",
    # Example: "abcd" const "123"% -> "abc"
    type: { [A,B] => A },
    min_zip_level: 1,
    impl: -> a,b { a.value }
  ), create_op(
    name: "and",
    sym: "&",
    # Example: 1&2 -> 2
    # Test: 0&2 -> 0
    type: { [A,B] => B },
    poly_impl: ->ta,tb { -> a,b { truthy(ta,a) ? b.value : tb.default_value }}
  ), create_op(
    name: "or",
    sym: "|",
    # Example: 1|2 -> 1
    # Test: 0|2 -> 2
    type: { [A,A] => A },
    poly_impl: ->ta,tb { -> a,b { truthy(ta,a) ? a.value : b.value }},
  ), create_op(
    name: "input",
    sym: "$",
    type: [Str],
    impl: -> { lines(ReadStdin) }
  ), create_op(
    # Hidden
    name: "tostring",
    # Example: 12 tostring -> "12"
    type: { A => Str },
    # Test: "a" tostring -> "a"
    # Test: 'a tostring -> "a"
    # Test: 2; 1 tostring -> "2 1"
    # Test: 2; 1; (3; 4) tostring -> "2 1\n3 4\n"
    no_zip: true,
    poly_impl: -> t { -> a { to_string(t.type+t.vec_level,a) } }
  ), create_op(
    name: "show",
    sym: "`",
    # Example: 12` -> "12"
    type: { A => Str },
    # Test: "a"` -> "\"a\""
    # Test: 'a` -> "'a"
    # Test: 1;` -> "[1]"
    no_zip: true,
    poly_impl: -> t { -> a { inspect_value(t.type+t.vec_level,a,t.vec_level) } }
  ), create_op(
    name: "single",
    sym: ";",
    # Example: 2; -> [2]
    type: { A => [A] },
    impl: -> a { [a,Null] }
  ), create_op(
    name: "take",
    sym: "[",
    # Example: "abcd"[3 -> "abc"
    # Test: "abc"[(2~) -> ""
    # Test: ""[2 -> ""
    type: { [[A],Int] => [A] },
    impl: -> a,b { take(b.value, a) }
  ), create_op(
    name: "drop",
    sym: "]",
    # Example: "abcd"]3 -> "d"
    # Test: "abc"](2~) -> "abc"
    # Test: ""]2 -> ""
    type: { [[A],Int] => [A] },
    impl: -> a,b { drop(b.value, a) }
  ), create_op(
    name: "range",
    # Example: 3 range 7 -> [3,4,5,6]
    type: { [Int,Int] => [Int],
            [Char,Char] => [Char] },
    impl: -> a,b { range(a.value, b.value) }
  ), create_op(
    name: "concat",
    sym: "_",
    # Example: "abc"; "123"_ -> "abc123"
    type: { [[A]] => [A] },
    impl: -> a { concat_map(a,Null){|i,r,first|append(i,r)} },
  ), create_op(
    name: "conjoin",
    sym: "‿",
    # Example: "abc" "123" -> ["abc","123"]
    type: { [[A],[A]] => [A] },
    no_zip: true,
    impl: -> a,b { append(a,b) }
  ), create_op(
    name: "append",
    sym: "_",
    # Example: "abc"_"123" -> "abc123"
    type: { [[A],[A]] => [A] },
    impl: -> a,b { append(a,b) }
  ), create_op(
    name: "cons",
    sym: "`",
    # Example: "abc"`'d -> "dabc"
    type: { [[A],A] => [A] },
    impl: -> a,b { [b,a] }
  ), create_op(
    name: "snoc",
    sym: ",",
    # Example: "abc",'d -> "abcd"
    type: { [[A],A] => [A] },
    impl: -> a,b { append(a,[b,Null].const) }
  ), create_op(
    name: "transpose",
    sym: "\\",
    # Example: "abc"; "123"\ -> ["a1","b2","c3"]
    # Test: "abc"; "1234"\ -> ["a1","b2","c3","4"]
    type: { [[A]] => [[A]] },
    impl: -> a { transpose(a) },
  ), create_op(
    name: "unzip",
    sym: "%",
    # Example: 1 2+3% -> [4,5]
    type: { VecOf.new(A) => [A] },
    impl: -> a { a.value },
  ), create_op(
    name: "zip",
    sym: ".",
    # Example: 1 2 3. -> <1,2,3>
    type: { [A] => VecOf.new(A) },
    impl: -> a { a.value },

  # Repl/Debug ops
  ), create_op(
    name: "type",
    # Example: 1 type -> "Int"
    # Test: "hi" type -> "[Char]"
    # Test: () type -> "Nil"
    type: { A => Str },
    no_zip: true,
    poly_impl: -> at { -> a { str_to_lazy_list(at.inspect) }},
  ), create_op(
    name: "version",
    type: Str,
    impl: -> { str_to_lazy_list("Atlas Alpha (Feb 26, 2023)") },
  ), create_op(
    name: "reductions",
    type: Int,
    impl: -> { $reductions },

  # Macros, type only used to specify number of args
  ), create_op(
    name: "let",
    sym: ":",
    type: { [A,A] => [A] },
    impl: MacroImpl,
  ), create_op(
    name: "push",
    # Example: 5{*2+} -> 15
    sym: "{",
    type: { A => A },
    impl: MacroImpl,
  ), create_op(
    name: "pop",
    # Example: 5{*2+} -> 15
    sym: "}",
    type: Int, # todo..
    impl: MacroImpl,
  ),

  create_op(
    name: "col1",
    type: [[Int]],
    impl: int_col(0)
  ), create_op(
    name: "col2",
    type: [[Int]],
    impl: int_col(1)
  ), create_op(
    name: "col3",
    type: [[Int]],
    impl: int_col(2)
  ), create_op(
    name: "col4",
    type: [[Int]],
    impl: int_col(3)
  )
]

Ops0 = {}
Ops1 = {}
Ops2 = {}
AllOps = {}
OpsList.each{|op|
  ops = case op.narg
  when 0
    Ops0[op.name] = Ops0[op.sym] = op
  when 1
    Ops1[op.name] = Ops1[op.sym] = op
  when 2
    Ops2[op.name] = Ops2[op.sym] = op
  else; error; end
  AllOps[op.name] = AllOps[op.sym] = op
}
AllOps[""]=Ops2[""]=Ops2[" "]
NilOp = AllOps['nil']
Var = Op.new("var")

def create_char(str)
  raise LexError.new("empty char") if str.size < 2
  create_op(
    sym: "data",
    name: "data",
    type: Char,
    impl: parse_char(str[1..-1]).ord
  )
end
