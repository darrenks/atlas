require_relative "./type.rb"
require_relative "./spec.rb"

MacroImpl = -> *args { raise "macro impl called" }

class Op < Struct.new(
    :name,
    :sym, # optional
    :type,
    :examples,
    :desc,
    :no_promote,
    :no_zip,
    :impl,
    :tests)
  def narg
    type ? type[0].specs.size : 0
  end
  def help(show_everything=true)
    puts "#{name} #{sym}"
    puts desc if desc
    type.each{|t|
      puts t.inspect.gsub('->','→').gsub('[Char]','Str')
    }
    (examples+tests*(show_everything ? 1 : 0)).each{|example|
      puts example.gsub('->','→')
    }
    misc = []
    puts "no_zip=true" if no_zip
    puts
  end
  def add_test(s)
    tests<<s
    self
  end
end

def create_op(
  name: nil,
  sym: nil,
  type: ,
  example: nil,
  example2: nil,
  example3: nil,
  no_promote: false,
  desc: nil,
  no_zip: false,
  poly_impl: nil, # impl that needs type info
  impl: nil,
  impl_with_loc: nil, # impl that could throw, needs token location for err msgs
  coerce: false,
  final_impl: nil
)
  type = create_specs(type)
  raise "exactly on of [poly_impl,impl,impl_with_loc,final_impl] must be set" if [poly_impl,impl,impl_with_loc,final_impl].compact.size != 1
  if poly_impl
    built_impl = -> arg_types,from { poly_impl[*arg_types] }
  elsif impl_with_loc
    built_impl = -> arg_types,from { impl_with_loc[from] }
  elsif final_impl
    built_impl = final_impl
  else
    built_impl = -> arg_types,from { Proc===impl ? impl : lambda { impl } }
  end
  examples = []
  examples << example if example
  examples << example2 if example2
  examples << example3 if example3

  if coerce
    f = built_impl
    built_impl = -> t,from { -> a,b { f[t,from][coerce2s(t[0],a,t[1]),coerce2s(t[1],b,t[0])] }}
  end

  Op.new(name,sym,type,examples,desc,no_promote,no_zip,built_impl,[])
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
    example: '"abc"[ -> \'a',
    type: { [A] => A },
    no_promote: true,
    impl_with_loc: -> from { -> a {
      raise DynamicError.new "head on empty list",from if a.empty
      a.value[0].value
    }},
  ), create_op(
    name: "last",
    sym: "]",
    no_promote: true,
    example: '"abc"] -> \'c',
    type: { [A] => A },
    impl_with_loc: -> from { -> a {
      raise DynamicError.new "last on empty list",from if a.empty
      last(a)
    }}
  ), create_op(
    name: "tail",
    example: '"abc"> -> "bc"',
    sym: ">",
    no_promote: true,
    type: { [A] => [A] },
    impl_with_loc: -> from { -> a {
      raise DynamicError.new "tail on empty list",from if a.empty
      a.value[1].value}}
  ), create_op(
    name: "init",
    example: '"abc"< -> "ab"',
    sym: "<",
    no_promote: true,
    type: { [A] => [A] },
    impl_with_loc: -> from { -> a {
      raise DynamicError.new "init on empty list",from if a.empty
      init(a)
    }}
  ), create_op(
    name: "add",
    sym: "+",
    example: "1+2 -> 3",
    example2: "'a+1 -> 'b",
    type: { [Int,Int] => Int,
            [Int,Char] => Char,
            [Char,Int] => Char },
    impl: -> a,b { a.value + b.value }
  ), create_op(
    name: "sub",
    sym: "-",
    example: '5-3 -> 2',
    type: { [Int,Int] => Int,
            [Char,Int] => Char,
            [Char,Char] => Int },
    impl: -> a,b { a.value - b.value }
  ), create_op(
    name: "mult",
    example: '2*3 -> 6',
    sym: "*",
    type: { [Int,Int] => Int },
    impl: -> a,b { a.value * b.value }
  ), create_op(
    name: "join",
    example: '"hi","yo"*" " -> "hi yo"',
    sym: "*",
    type: { [[Str],Str] => Str,
            [[Int],Str] => Str,},
    poly_impl: -> at,bt { -> a,b { join(coerce2s(at,a,Str+1),b) } })
  .add_test('1,2,3*", " -> "1, 2, 3"'),
  create_op(
    name: "split",
    example: '"hi, yo"/", " -> ["hi","yo"]',
    sym: "/",
    type: { [Str,Str] => [Str] },
    impl: -> a,b { split(a,b) })
  .add_test('"abcbcde"/"bcd" -> ["abc","e"]')
  .add_test('"ab",*" "/"b "[2 -> ["a","a"]') # test laziness
  .add_test('",a,,b,"/"," -> ["a","b"]'),
  create_op(
    name: "pow",
    example: '2^3 -> 8',
    sym: "^",
    type: { [Int,Int] => Int },
    impl: -> a,b { a.value ** b.value } # todo use formula that will always be int
  ), create_op(
    name: "replicate",
    example: '"ab"^3 -> "ababab"',
    sym: "^",
    type: { [Str,Int] => Str },
    impl: -> a,b { concat(take(b.value,repeat(a).const).const) }
  ), create_op(
    name: "div",
    example: '7/3 -> 2',
    sym: "/",
    type: { [Int,Int] => Int },
    impl_with_loc: -> from { -> a,b {
      if b.value==0
        raise DynamicError.new("div 0", from) # todo maybe too complicated to be worth it same for mod
      else
        a.value/b.value
      end
    }})
   .add_test("10/5 -> 2")
   .add_test("9/5 -> 1")
   .add_test("11/(5~) -> -3")
   .add_test("10/(5~) -> -2")
   .add_test("11~/5 -> -3")
   .add_test("10~/5 -> -2")
   .add_test("10~/(5~) -> 2")
   .add_test("9~/(5~) -> 1")
   .add_test("1/0 -> DynamicError")
   .add_test("0/0 -> DynamicError"),
  create_op(
    name: "mod",
    example: '7%3 -> 1',
    sym: "%",
    type: { [Int,Int] => Int },
    impl_with_loc: -> from { -> a,b {
      if b.value==0
        raise DynamicError.new("mod 0",from)
      else
        a.value % b.value
      end
    }})
   .add_test("10%5 -> 0")
   .add_test("9%5 -> 4")
   .add_test("11%(5~) -> -4")
   .add_test("10%(5~) -> 0")
   .add_test("11~%5 -> 4")
   .add_test("10~%5 -> 0")
   .add_test("10~%(5~) -> 0")
   .add_test("9~%(5~) -> -4")
   .add_test("5%0 -> DynamicError"),
  create_op(
    name: "not",
    type: { A => Int },
    example: '2 not -> 0',
    poly_impl: -> ta { -> a { truthy(ta,a) ? 0 : 1 } }
  ), create_op(
    name: "neg",
    sym: "~",
    type: { Int => Int },
    example: '2~ -> -2',
    impl: -> a { -a.value }
  ), create_op(
    name: "abs",
    sym: "|",
    type: { Int => Int },
    example: '2~| -> 2',
    impl: -> a { a.value.abs }
  ), create_op(
    name: "read",
    sym: "~",
    type: { Str => [Int] },
    example: '"1 2 -3 4a5 - -6 --7" ~ -> [1,2,-3,4,5,-6,7]',
    impl: -> a { split_non_digits(a) }
  ), create_op(
    name: "repeat",
    sym: ",",
    example: '2, -> <2,2,2,2,2...',
    type: { A => VecOf.new(A) },
    impl: -> a { repeat(a) }
  ), create_op(
    name: "eq",
    example: '3=3 -> [3]',
    sym: "=",
    type: { [A,A] => [A] },
    poly_impl: -> ta,tb {-> a,b { spaceship(a,b,ta) == 0 ? [b,Null] : [] } })
  .add_test("3=2 -> []")
  .add_test("1=2 -> []")
  .add_test("1=1 -> [1]")
  .add_test('\'a=\'a -> "a"')
  .add_test("'d=100 -> AtlasTypeError")
  .add_test('"abc"="abc" -> ["abc"]')
  .add_test('"abc"="abd" -> []')
  .add_test('"abc"=\'a -> <"a","","">')
  .add_test('"abc"=(\'a.) -> <"a">')
  .add_test('"abc".="abd" -> <"a","b","">'),
  create_op(
    name: "lessThan",
    example: '4<5 -> [5]',
    sym: "<",
    type: { [A,A] => [A] },
    poly_impl: -> ta,tb {-> a,b { spaceship(a,b,ta) == -1 ? [b,Null] : [] } }
  ).add_test("5<4 -> []"),
  create_op(
    name: "greaterThan",
    example: '5>4 -> [4]',
    sym: ">",
    type: { [A,A] => [A] },
    poly_impl: -> ta,tb {-> a,b { spaceship(a,b,ta) == 1 ? [b,Null] : [] } }
  ).add_test("4>5 -> []"),
  create_op(
    name: "len",
    example: '"asdf"# -> 4',
    sym: "#",
    type: { [A] => Int },
    impl: -> a { len(a) }
  ), create_op(
    name: "and",
    sym: "&",
    example: '1&2 -> 2',
    type: { [A,B] => B },
    poly_impl: ->ta,tb { -> a,b { truthy(ta,a) ? b.value : tb.default_value }}
  ).add_test("0&2 -> 0"),
  create_op(
    name: "or",
    sym: "|",
    example: '1|2 -> 1',
    example2: '1|"b" -> "1"',
    example3: '"b"|3 -> "b"',
    type: { [A,A] => A,
            [Aint,[Achar]] => [Achar],
            [[Achar],Aint] => [Achar] },
    poly_impl: ->ta,tb { -> a,b { truthy(ta,a) ? coerce2s(ta,a,tb).value : coerce2s(tb,b,ta).value }},
  ).add_test("0|2 -> 2")
   .add_test('0|"b" -> "b"')
   .add_test('""|2 -> "2"')
   .add_test(' 0|\'c -> "c"'),
  create_op(
    name: "input",
    sym: "$",
    type: [Str],
    impl: -> { lines(ReadStdin) }
  ), create_op(
    name: "show",
    sym: "`",
    example: '12` -> "12"',
    type: { A => Str },
    no_zip: true,
    poly_impl: -> t { -> a { inspect_value(t.type+t.vec_level,a,t.vec_level) } }
  ).add_test('"a"` -> "\"a\""')
   .add_test('\'a` -> "\'a"')
   .add_test('1;` -> "[1]"'),
  create_op(
    name: "str",
    example: '12 str -> "12"',
    type: { Int => Str },
    impl: -> a { inspect_value(Int,a,0) }
  ), create_op(
    name: "single",
    sym: ";",
    example: '2; -> [2]',
    type: { A => [A] },
    impl: -> a { [a,Null] }
  ), create_op(
    name: "take",
    sym: "[",
    example: '"abcd"[3 -> "abc"',
    type: { [[A],Int] => [A] },
    impl: -> a,b { take(b.value, a) }
  ).add_test('"abc"[(2~) -> ""')
   .add_test('""[2 -> ""'),
  create_op(
    name: "drop",
    sym: "]",
    example: '"abcd"]3 -> "d"',
    type: { [[A],Int] => [A] },
    impl: -> a,b { drop(b.value, a) }
  ).add_test('"abc"](2~) -> "abc"')
   .add_test('""]2 -> ""'),
  create_op(
    name: "range",
    example: '3 range 7 -> <3,4,5,6>',
    type: { [Int,Int] => VecOf.new(Int),
            [Char,Char] => VecOf.new(Char) },
    impl: -> a,b { range(a.value, b.value) }
  ), create_op(
    name: "from",
    example: '3 from -> <3,4,5,6,7,8...',
    type: { Int => VecOf.new(Int),
            Char => VecOf.new(Char) },
    impl: -> a { range_from(a.value) }
  ), create_op(
    name: "count",
    example: '"abcaab" count -> [0,0,0,1,2,1]',
    type: { [A] => [Int] },
    impl: -> a { occurence_count(a) }
  ).add_test('"ab","a","ab" count -> [0,0,1]'),
  create_op(
    name: "filter",
    example: '"abcd" filter (0,1,1,0) -> "bc"',
    type: { [[A],[B]] => [A] },
    poly_impl: -> at,bt { -> a,b { filter(a,b,bt-1) }}
  ), create_op(
    name: "sort",
    example: '"atlas" sort -> "aalst"',
    type: { [A] => [A] },
    poly_impl: -> at { -> a { sort(a,at-1) }}
  ), create_op(
    name: "sortBy",
    example: '"abc" sortBy (3,1,2) -> "bca"',
    type: { [[A],[B]] => [A] },
    poly_impl: -> at,bt { -> a,b { sortby(a,b,bt-1) }})
  .add_test('1,2,3 sortBy ("hi","there") -> [1,2]'),
  create_op(
    name: "chunkWhile",
    example: '"abcd" chunkWhile "11 1" -> [["ab","c"],["d",""]]',
    type: { [[A],[B]] => [[[A]]] },
    poly_impl: -> at,bt { -> a,b { chunk_while(a,b,bt-1) } })
  .add_test('"abcd" chunkWhile " 11 " -> [["","a"],["bc","d"]]'),
  create_op(
    name: "concat",
    sym: "_",
    no_promote: true,
    example: '"abc","123"_ -> "abc123"',
    type: { [[A]] => [A] },
    impl: -> a { concat(a) },
  ), create_op(
    name: "implicitMult",
    sym: " ",
    example: '2 3 -> 6',
    type: { [Int,Int] => Int },
    impl: -> a,b { a.value*b.value }
  ), create_op(
    name: "implicitAppend",
    sym: " ",
    example: '1"a" -> "1a"',
    type: { [Str,Str] => Str,
            [Aint,[Achar]] => [Achar],
            [[Achar],Aint] => [Achar] },
    impl: -> a,b { append(a,b) },
    coerce: true)
  .add_test("'a 'b -> \"ab\"")
  .add_test('"ab","cd" "e" -> <"abe","cde">'),
  create_op(
    name: "append",
    sym: "_",
    example: '"abc"_"123" -> "abc123"',
    type: { [[A],[A]] => [A],
            [Aint,[Achar]] => [Achar],
            [[Achar],Aint] => [Achar] },
    impl: -> a,b { append(a,b) },
    coerce: true)
  .add_test('1_"a" -> "1a"'),
  create_op(
    name: "cons",
    sym: "`",
    example: '"abc"`\'d -> "dabc"',
    type: { [[A],A] => [A],
            [Aint,Achar] => [Achar],
            [[[Achar]],Aint] => [[Achar]] },
    poly_impl: -> ta,tb {-> a,b { [coerce2s(tb,b,ta-1),coerce2s(ta-1,a,tb)] }})
  .add_test('\'a`5 -> ["5","a"]')
  .add_test('5`\'a -> "a5"')
  .add_test('\'b`\'a -> "ab"'),
  create_op(
    name: "snoc",
    desc: "this op prefers to promote the 2nd arg once rather than vectorize it in order for inuitive list construction",
    sym: ",",
    example: '1,2,3 -> [1,2,3]',
    type: { [[A],A] => [A],
            [Aint,Achar] => [Achar],
            [[[Achar]],Aint] => [[Achar]] },
    poly_impl: -> ta,tb {-> a,b { append(coerce2s(ta-1,a,tb),[coerce2s(tb,b,ta-1),Null].const) }}
  ).add_test("2,1 -> [2,1]")
  .add_test('(2,3),1 -> [2,3,1]')
  .add_test('(2,3),(4,5),1 -> <[2,3,1],[4,5,1]>')
  .add_test('2,(1,0) -> [[2],[1,0]]')
  .add_test('(2,3),(1,0) -> [[2,3],[1,0]]')
  .add_test('(2,3).,1 -> <[2,1],[3,1]>')
  .add_test('(2,3),(4,5).,1 -> <[2,3,1],[4,5,1]>')
  .add_test('2,(1,0.) ->  <[2,1],[2,0]>')
  .add_test('(2,3),(1,0.) -> <[2,3,1],[2,3,0]>')
  .add_test('\'a,5 -> ["a","5"]')
  .add_test('5,\'a -> "5a"')
  .add_test('\'b,\'a -> "ba"'),
  create_op(
    name: "transpose",
    sym: "\\",
    example: '"abc","123"\\ -> ["a1","b2","c3"]',
    type: { [[A]] => [[A]] },
    impl: -> a { transpose(a) },
  ).add_test('"abc","1234"\ -> ["a1","b2","c3","4"]'),
  create_op(
    name: "reverse",
    sym: "/",
    example: '"abc" reverse -> "cba"',
    type: { [A] => [A] },
    impl: -> a { reverse(a) },
  ), create_op(
    name: "unvec",
    sym: "%",
    example: '1,2+3% -> [4,5]',
    type: { VecOf.new(A) => [A] },
    impl: -> a { a.value },
  ), create_op(
    name: "vectorize",
    sym: ".",
    example: '1,2,3. -> <1,2,3>',
    type: { [A] => VecOf.new(A) },
    impl: -> a { a.value },

  # Repl/Debug ops
  ), create_op(
    name: "type",
    example: '1 type -> "Int"',
    type: { A => Str },
    no_zip: true,
    poly_impl: -> at { -> a { str_to_lazy_list(at.inspect) }})
  .add_test('"hi" type -> "[Char]"')
  .add_test('() type -> "[A]"'),
  create_op(
    name: "version",
    type: Str,
    impl: -> { str_to_lazy_list("Atlas Alpha (Mar 10, 2023)") }
  ), create_op(
    name: "reductions",
    desc: "operation count so far",
    type: Int,
    impl: -> { $reductions }),

  # Macros, type only used to specify number of args
  create_op(
    name: "let",
    example: '5@a+a -> 10',
    sym: ApplyModifier,
    type: { [A,A] => [A] },
    impl: MacroImpl,
  ), create_op(
    name: "push",
    desc: "duplicate arg onto the stack",
    example: '5{*2+} -> 15',
    sym: "{",
    type: { A => A },
    impl: MacroImpl,
  ), create_op(
    name: "pop",
    desc: "pop last push arg from the stack",
    example: '5{*2+} -> 15',
    sym: "}",
    type: A,
    impl: MacroImpl,
  )
]

Ops0 = {}
Ops1 = {}
Ops2 = {}
AllOps = {}

def addOp(table,op)
  if (existing=table[op.sym])
    combined_type = {}
    op.type.each{|s|combined_type[s.orig_key]=s.orig_val}
    existing.type.each{|s|combined_type[s.orig_key]=s.orig_val}
    combined_impl = -> arg_types,from {
      if existing.type.any?{|fn_type|
        check_base_elem_constraints(fn_type.specs, arg_types)
      }
        existing.impl[arg_types,from]
      else
        op.impl[arg_types,from]
      end
    }
    combined = create_op(
      sym: op.sym,
      type: combined_type,
      final_impl: combined_impl,
    )
    table[op.sym] = combined
  else
    table[op.sym] = op
  end
  table[op.name] = op
end

OpsList.each{|op|
  ops = case op.narg
  when 0
    addOp(Ops0, op)
  when 1
    addOp(Ops1, op)
  when 2
    addOp(Ops2, op)
  else; error; end
  raise "name conflict #{op.name}" if AllOps.include? op.name
  AllOps[op.name] = AllOps[op.sym] = op
}
AllOps[""]=Ops2[""]=Ops2[" "] # allow @ to flip the implicit op (todo pointless for multiplication)
EmptyOp = create_op(
  name: "empty",
  type: Empty,
  impl: [])
UnknownOp = create_op(
  name: "unknown",
  type: Unknown,
  impl_with_loc: -> from { raise AtlasTypeError.new("cannot use value of the unknown type", from) }
)
Var = Op.new("var")
ToString = create_op(
  name: "tostring",
  type: { A => Str },
  no_zip: true,
  poly_impl: -> t { -> a { to_string(t.type+t.vec_level,a) } }
)

def create_int(str)
  create_op(
    name: "data",
    type: Int,
    impl: str.to_i
  )
end

def create_str(str)
  raise LexError.new("unterminated string") if str[-1] != '"'
  create_op(
    name: "data",
    type: Str,
    impl: str_to_lazy_list(parse_str(str[1...-1]))
  )

end
def create_char(str)
  raise LexError.new("empty char") if str.size < 2
  create_op(
    name: "data",
    type: Char,
    impl: parse_char(str[1..-1]).ord
  )
end
