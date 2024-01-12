# -*- coding: ISO-8859-1 -*-
require_relative "./type.rb"
require_relative "./spec.rb"

MacroImpl = -> *args { raise "macro impl called" }

class Op < Struct.new(
    :name,
    :sym, # optional
    :type,
    :type_summary,
    :examples,
    :desc,
    :ref_only,
    :no_promote,
    :impl,
    :tests)
  def narg
    type ? type[0].specs.size : 0
  end
  def help(out=STDOUT)
    out.puts "#{name} #{sym}"
    out.puts desc if desc
    if type_summary
      out.puts type_summary
    else
      type.each{|t|
        out.puts t.inspect.gsub('->',"\xE2\x86\x92").gsub('[Char]','Str')
      }
    end
    (examples+tests).each{|example|
      out.puts example.gsub('->',"\xE2\x86\x92")
    }
    misc = []
    out.puts
  end
  def add_test(s)
    tests<<s
    self
  end
end

class String
  def help(unused=true)
    puts
    puts "#"*(self.size+4)
    puts "# "+self+" #"
    puts "#"*(self.size+4)
    puts
  end
end

def create_op(
  name: nil,
  sym: nil,
  type: ,
  type_summary: nil,
  example: nil,
  example2: nil,
  no_promote: false,
  desc: nil,
  ref_only: false,
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

  if coerce
    f = built_impl
    built_impl = -> t,from { -> a,b { f[t,from][coerce2s(t[0],a,t[1]),coerce2s(t[1],b,t[0])] }}
  end

  Op.new(name,sym,type,type_summary,examples,desc,ref_only,no_promote,built_impl,[])
end

def num_col
  map(lines(ReadStdin).const){|v|
    v = split_non_digits(v)
    raise DynamicError.new "num col: empty list",nil if v==[]
    v[0].value
  }
end

OpsList = [
  "math",
  create_op(
    name: "add",
    sym: "+",
    example: "1+2 -> 3",
    example2: "'a+1 -> 'b",
    type: { [Num,Num] => Num,
            [Num,Char] => Char,
            [Char,Num] => Char },
    impl: -> a,b { a.value + b.value })
   .add_test("'a+1.2 -> 'b"),
  create_op(
    name: "sum",
    sym: "+",
    example: "1,2,3,4+ -> 10",
    type: { [Num] => Num },
    no_promote: true,
    impl: -> a { sum(a) })
   .add_test("1;>+ -> 0"),
  create_op(
    name: "sub",
    sym: "-",
    example: '5-3 -> 2',
    example2: "'b-'a -> 1",
    type: { [Num,Num] => Num,
            [Char,Num] => Char,
            [Num,Char] => Char,
            [Char,Char] => Num },
    poly_impl: ->at,bt { flipif bt.is_char && !at.is_char, -> a,b { a.value - b.value }})
   .add_test("1-'b -> 'a"),
  create_op(
    name: "mult",
    example: '2*3 -> 6',
    sym: "*",
    type: { [Num,Num] => Num },
    impl: -> a,b { a.value * b.value }),
  create_op(
    name: "prod",
    sym: "*",
    example: "1,2,3,4* -> 24",
    no_promote: true,
    type: { [Num] => Num },
    impl: -> a { prod(a) })
   .add_test("1;>* -> 1"),
  create_op(
    name: "div",
    desc: "0/0 is 0",
    example: '7/3 -> 2',
    sym: "/",
    type: { [Num,Num] => Num },
    impl_with_loc: -> from { -> a,b {
      if b.value==0
        if a.value == 0
          0
        else
          raise DynamicError.new("div 0", from)
        end
      else
        a.value/b.value
      end
    }})
   .add_test("10/5 -> 2")
   .add_test("9/5 -> 1")
   .add_test("11/(5-) -> -3")
   .add_test("10/(5-) -> -2")
   .add_test("11-/5 -> -3")
   .add_test("10-/5 -> -2")
   .add_test("10-/(5-) -> 2")
   .add_test("9-/(5-) -> 1")
   .add_test("1/0 -> DynamicError")
   .add_test("0/0 -> 0"),
  create_op(
    name: "mod",
    desc: "anything mod 0 is 0",
    example: '7%3 -> 1',
    sym: "%",
    type: { [Num,Num] => Num },
    impl_with_loc: -> from { -> a,b {
      if b.value==0
        0
      else
        a.value % b.value
      end
    }})
   .add_test("10%5 -> 0")
   .add_test("9%5 -> 4")
   .add_test("11%(5-) -> -4")
   .add_test("10%(5-) -> 0")
   .add_test("11-%5 -> 4")
   .add_test("10-%5 -> 0")
   .add_test("10-%(5-) -> 0")
   .add_test("9-%(5-) -> -4")
   .add_test("5%0 -> 0"),
  create_op(
    name: "pow", # consider allowing rationals or even imaginary numbers
    desc: "negative exponent will result in a rational, but this behavior is subject to change and not officially supported, similarly for imaginary numbers",
    example: '2^3 -> 8',
    sym: "^",
    type: { [Num,Num] => Num },
    impl: -> a,b { a.value ** b.value }),
  create_op(
    name: "neg",
    sym: "-",
    type: { Num => Num },
    example: '2- -> -2',
    impl: -> a { -a.value }
  ), create_op(
    name: "abs",
    sym: "|",
    type: { Num => Num },
    example: '2-| -> 2',
    example2: '2| -> 2',
    impl: -> a { a.value.abs }),
  create_op(
    name: "floor",
    sym: "&",
    type: { Num => Num },
    example: '1.3& -> 1',
    impl: -> a { a.value.floor }),
  create_op(
    name: "toBase",
    sym: ";",
    type: { [Num,Num] => [Num],
            [Num,Char] => Str },
    example: '6;2 -> [0,1,1]',
    impl: -> a,b { to_base(a.value.abs,b.value,a.value<=>0) })
   .add_test('3,3.;2 -> <[1,1],[1,1]>')
   .add_test('6;(2-) -> [0,-1,-1,-1]')
   .add_test('6-;2 -> [0,-1,-1]')
   .add_test('5.5;2 -> [1.5,0.0,1.0]')
   .add_test('5.5-;2 -> [-1.5,-0.0,-1.0]'),
  create_op(
    name: "fromBase",
    sym: ";",
    type: { [[Num],Num] => Num,
            [Str,Num] => Num,
            [Str,Char] => Num },
    example: '0,1,1;2 -> 6',
    impl: -> a,b { from_base(a,b.value) })
   .add_test('0,1,1,1-%;(2-) -> 6')
   .add_test('0,1,1-%;2 -> -6')
   .add_test('1.5,0.0,1.0;2 -> 5.5')
   .add_test('"abc";\'d -> 999897'),
  "vector",
  create_op(
    name: "unvec",
    sym: "%",
    example: '1,2+3% -> [4,5]',
    type: { v(A) => [A] },
    impl: -> a { a.value },
  ), create_op(
    name: "vectorize",
    sym: ".",
    example: '1,2,3. -> <1,2,3>',
    type: { [A] => v(A) },
    impl: -> a { a.value }),
  create_op(
    name: "range",
    sym: ":",
    example: '3:7 -> <3,4,5,6>',
    type: { [Num,Num] => v(Num),
            [Char,Char] => v(Char) },
    impl: -> a,b { range(a.value, b.value) })
   .add_test("5:3 -> <>")
   .add_test("1.5:5 -> <1.5,2.5,3.5,4.5>"),
  create_op(
    name: "from",
    sym: ":",
    example: '3: -> <3,4,5,6,7,8...',
    type: { Num => v(Num),
            Char => v(Char) },
    impl: -> a { range_from(a.value) }),
  create_op(
    name: "consDefault",
    sym: "^",
    example: '2,3.^ -> <0,2,3>',
    type: { v(A) => v(A) },
    type_summary: "<a> -> <a>\n[a] -> [a]",
    poly_impl: -> at { d=(at-1).default_value.const; -> a { [d,a] }})
    .add_test("1,2^ -> [0,1,2]")
    .add_test("1^ -> <0,1>"),
  "basic list",
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
    name: "len",
    example: '"asdf"# -> 4',
    sym: "#",
    type: { [A] => Num },
    no_promote: true,
    impl: -> a { len(a) }),
  create_op(
    name: "take",
    sym: "[",
    example: '"abcd"[3 -> "abc"',
    type: { [[A],Num] => [A],
            [Num,[Achar]] => [A] },
    poly_impl: ->at,bt { flipif bt.is_char, -> a,b { take(b.value, a) }}
  ).add_test('"abc"[(2-) -> ""')
   .add_test('"abc"[1.2 -> "a"')
   .add_test('1["abc" -> "a"')
   .add_test('""[2 -> ""'),
  create_op(
    name: "drop",
    sym: "]",
    example: '"abcd"]3 -> "d"',
    type: { [[A],Num] => [A],
            [Num,[Achar]] => [A] },
    poly_impl: ->at,bt { flipif bt.is_char, -> a,b { drop(b.value, a) }}
  ).add_test('"abc"](2-) -> "abc"')
   .add_test('"abc"]1.2 -> "bc"')
   .add_test('1]"abc" -> "bc"')
   .add_test('""]2 -> ""'),
  create_op(
    name: "single",
    sym: ";",
    example: '2; -> [2]',
    type: { A => [A] },
    impl: -> a { [a,Null] }),
  create_op(
    name: "repeat",
    sym: ",",
    example: '2, -> [2,2,2,2,2...',
    type: { A => [A] },
    impl: -> a { repeat(a) }),
  create_op(
    name: "concat",
    sym: "_",
    no_promote: true,
    example: '"abc","123"_ -> "abc123"',
    type: { [[A]] => [A] },
    impl: -> a { concat(a) }),
  create_op(
    name: "append",
    sym: "_",
    example: '"abc"_"123" -> "abc123"',
    type: { [[A],[A]] => [A],
            [Anum,[Achar]] => [Achar],
            [[Achar],Anum] => [Achar] },
    type_summary: "[*a] [*a] -> [a]",
    impl: -> a,b { append(a,b) },
    coerce: true)
  .add_test('1_"a" -> "1a"'),
  create_op(
    name: "cons",
    sym: "`",
    example: '1`2`3 -> [3,2,1]',
    type: { [[A],A] => [A],
            [Anum,Achar] => [Achar],
            [[[Achar]],Anum] => [[Achar]] },
    type_summary: "[*a] *a -> [a]",
    poly_impl: -> ta,tb {-> a,b { [coerce2s(tb,b,ta-1),coerce2s(ta,a,tb+1)] }})
  .add_test('\'a`5 -> ["5","a"]')
  .add_test('"a"`(5) -> ["5","a"]')
  .add_test('"a";;`(5;) -> [["5"],["a"]]')
  .add_test("5`\'a -> \"a5\"")
  .add_test('5;`"a" -> ["a","5"]')
  .add_test('\'b`\'a -> "ab"'),
create_op(
    name: "build",
    sym: ",",
    example: '1,2,3 -> [1,2,3]',
    type: { [[A],[A]] => [A],
            [Anum,[Achar]] => [Achar],
            [[Achar],Anum] => [Achar] },
    type_summary: "*a *a -> [a]\n[*a] *a -> [a]\n*a [*a] -> [a]",
    poly_impl: -> ta,tb {-> a,b {
    append(coerce2s(ta,a,tb),coerce2s(tb,b,ta))
    }}
  ).add_test("2,1 -> [2,1]")
  .add_test('(2,3),1 -> [2,3,1]')
  .add_test('(2,3),(4,5),1 -> <[2,3,1],[4,5,1]>')
  .add_test('2,(1,0) -> [2,1,0]')
  .add_test('(2,3),(1,0) -> [[2,3],[1,0]]')
  .add_test('(2,3).,1 -> <[2,1],[3,1]>')
  .add_test('(2,3),(4,5).,1 -> <[2,3,1],[4,5,1]>')
  .add_test('2,(1,0.) ->  <[2,1],[2,0]>')
  .add_test('(2,3),(1,0.) -> <[2,3,1],[2,3,0]>')
  .add_test('\'a,5 -> "a5"')
  .add_test('5,\'a -> "5a"')
  .add_test('5,"a" -> ["5","a"]')
  .add_test('\'b,\'a -> "ba"'),
  "more list",
  create_op(
    name: "count",
    desc: "count the number of times each element has occurred previously",
    sym: "=",
    example: '"abcaab" = -> [0,0,0,1,2,1]',
    type: { [A] => [Num] },
    no_promote: true,
    impl: -> a { occurence_count(a) }
  ).add_test('"ab","a","ab" count -> [0,0,1]'),
  create_op(
    name: "filterFrom",
    sym: "~",
    example: '0,1,1,0 ~ "abcd" -> "bc"',
    type: { [v(A),[B]] => [B] },
    poly_impl: -> at,bt { -> a,b { filter(b,a,at-1) }}),
  create_op(
    name: "sort",
    desc: "O(n log n) sort - not optimized for lazy O(n) min/max yet todo",
    sym: "!",
    example: '"atlas" ! -> "aalst"',
    type: { [A] => [A] },
    no_promote: true,
    poly_impl: -> at { -> a { sort(a,at-1) }}
  ), create_op(
    name: "sortFrom",
    desc: "stable O(n log n) sort - not optimized for lazy O(n) min/max yet todo",
    sym: "!",
    example: '3,1,4 ! "abc" -> "bac"',
    type: { [v(A),[B]] => [B] },
    poly_impl: -> at,bt { -> a,b { sortby(b,a,at-1) }})
  .add_test('"hi","there" ! (1,2,3) -> [1,2]')
  .add_test('"aaaaaa" ! "abcdef" -> "abcdef"'),
  create_op(
    name: "chunk",
    desc: "chunk while truthy",
    sym: "?",
    example: '"12 3"? -> ["12","3"]',
    type: { [A] => [[A]] },
    poly_impl: -> at { -> a { chunk_while(a,a,at-1) } }),
  create_op(
    name: "chunkFrom",
    desc: "chunk while first arg is truthy",
    sym: "?",
    example: '"11 1" ? "abcd" -> ["ab","d"]',
    type: { [v(A),[B]] => [[B]] },
    poly_impl: -> at,bt { -> a,b { chunk_while(b,a,at-1) } })
  .add_test('" 11  " ? "abcde" -> ["","bc","",""]')
  .add_test('()?"" -> [""]'),
  create_op(
    name: "transpose",
    sym: "\\",
    example: '"abc","1"\\ -> ["a1","b","c"]',
    type: { [[A]] => [[A]] },
    impl: -> a { transpose(a) },
  ).add_test('"abc","1234"\ -> ["a1","b2","c3","4"]'),
  create_op(
    name: "reverse",
    sym: "/",
    example: '"abc" / -> "cba"',
    type: { [A] => [A] },
    no_promote: true,
    impl: -> a { reverse(a) }),
  create_op(
    name: "reshape",
    sym: "#",
    desc: "Take elements in groups of sizes. If second list runs out, last element is repeated",
    example: '"abcdef"#2 -> ["ab","cd","ef"]',
    type: { [[A],[Num]] => [[A]],
            [[Num],[Achar]] => [[A]] },
    poly_impl: ->at,bt { flipif bt.is_char, -> a,b { reshape(a,b) }})
   .add_test('"abc" # 2 -> ["ab","c"]')
   .add_test('"abcd" # (2,1) -> ["ab","c","d"]')
   .add_test('"."^10#2.5*" " -> ".. ... .. ..."')
   .add_test('2#"abcd" -> ["ab","cd"]')
   .add_test('"" # 2 -> []'),
  "string",
  create_op(
    name: "join",
    example: '"hi","yo"*" " -> "hi yo"',
    sym: "*",
    type: { [[Str],Str] => Str,
            [[Num],Str] => Str,},
    poly_impl: -> at,bt { -> a,b { join(coerce2s(at,a,Str+1),b) } })
  .add_test('1,2,3*", " -> "1, 2, 3"'),
  create_op(
    name: "split",
    desc: "split, keeping empty results (include at beginning and end)",
    example: '"hi, yo"/", " -> ["hi","yo"]',
    sym: "/",
    type: { [Str,Str] => [Str] },
    impl: -> a,b { split(a,b) })
  .add_test('"abcbcde"/"bcd" -> ["abc","e"]')
  .add_test('"ab",*" "/"b "[2 -> ["a","a"]') # test laziness
  .add_test('",a,,b,"/"," -> ["","a","","b",""]'),
  create_op(
    name: "replicate",
    example: '"ab"^3 -> "ababab"',
    sym: "^",
    type: { [Str,Num] => Str,
            [Num,Str] => Str },
    poly_impl: -> ta,tb { flipif !ta.is_char, -> a,b {
      ipart = concat(take(b.value,repeat(a).const).const)
      if b.value.class == Integer
        ipart
      else
        append(ipart.const, take(b.value%1*len(a), a).const)
      end
    }})
   .add_test('2^"ab" -> "abab"')
   .add_test('"abcd"^2.5 -> "abcdabcdab"'),
  create_op(
    name: "ord",
    example: "'a& -> 97",
    sym: "&",
    type: { Char => Num },
    impl: -> a { a.value }),
  "logic",
  create_op(
    name: "equalTo",
    example: '3=3 -> [3]',
    example2: '3=0 -> []',
    sym: "=",
    type: { [A,A] => [A] },
    poly_impl: -> ta,tb {-> a,b { spaceship(a,b,ta) == 0 ? [a,Null] : [] } })
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
    example: '4<5 -> [4]',
    example2: '5<4 -> []',
    sym: "<",
    type: { [A,A] => [A] },
    poly_impl: -> ta,tb {-> a,b { spaceship(a,b,ta) == -1 ? [a,Null] : [] } }
  ).add_test("5<4 -> []"),
  create_op(
    name: "greaterThan",
    example: '5>4 -> [5]',
    example2: '4>5 -> []',
    sym: ">",
    type: { [A,A] => [A] },
    poly_impl: -> ta,tb {-> a,b { spaceship(a,b,ta) == 1 ? [a,Null] : [] } }
  ).add_test("4>5 -> []"),
  create_op(
    name: "not",
    sym: "~",
    type: { A => Num },
    example: '2~ -> 0',
    example2: '0~ -> 1',
    poly_impl: -> ta { -> a { truthy(ta,a) ? 0 : 1 } }),
  create_op(
    name: "and",
    sym: "&",
    example: '1&2 -> 2',
    example2: '1-&2 -> -1',
    type: { [A,B] => B },
    poly_impl: ->ta,tb { -> a,b { truthy(ta,a) ? b.value : (ta==tb ? a.value : tb.default_value) }}
  ),
  create_op(
    name: "or",
    sym: "|",
    example: '2|0 -> 2',
    example2: '0|2 -> 2',
    type: { [A,A] => A,
            [Anum,[Achar]] => [Achar],
            [[Achar],Anum] => [Achar] },
    type_summary: "*a *a -> a",
    poly_impl: ->ta,tb { -> a,b { truthy(ta,a) ? coerce2s(ta,a,tb).value : coerce2s(tb,b,ta).value }},
  ).add_test("0|2 -> 2")
   .add_test('1|"b" -> "1"')
   .add_test('"b"|3 -> "b"')
   .add_test('0|"b" -> "b"')
   .add_test('""|2 -> "2"')
   .add_test(' 0|\'c -> "c"'),
  create_op(
    name: "catch",
    sym: "tbd",
    example: '1/0 catch -> []',
    example2: '1/1 catch -> [1]',
    type: { A => [A] },
    impl: -> a {
      begin
        a.value
        [a, Null]
      rescue AtlasError # dynamic and inf loop
        []
      end
    }),
  '"io"',
  create_op(
    name: "readLines",
    desc: "all lines of stdin",
    type: v(Str),
    impl: -> { lines(ReadStdin) }),
  create_op(
    name: "firstNums",
    desc: "first num column from stdin",
    type: v(Num),
    impl: -> { num_col },
  ),
  create_op(
    name: "read",
    sym: "`",
    type: { Str => [Num] },
    example: '"1 2 -3"` -> [1,2,-3]',
    impl: -> a { split_non_digits(a) })
  .add_test('"1 2.30 -3 4a5 - -6 --7 .8" ` -> [1,2.3,-3,4,5,-6,7,8]'),
  create_op(
    name: "str",
    sym: "`",
    example: '12` -> "12"',
    type: { Num => Str },
    impl: -> a { inspect_value(Num,a,0) }),
  "syntactic sugar",
  # Macros, type only used to specify number of args
  create_op(
    name: "set",
    desc: "save to a variable without consuming it",
    example: '5@a+a -> 10',
    sym: ApplyModifier,
    type: { [A,:id] => A },
    impl: MacroImpl,
  ), create_op(
    name: "save",
    desc: "save to next available var (a,b,c,...)",
    example: '5{,1,a,2 -> [5,1,5,2]',
    sym: "{",
    type: { A => A },
    impl: MacroImpl),

  # These are here purely for quickref purposes
  create_op(
    name: "flip",
    sym: "\\",
    desc: "reverse order of previous op's args",
    example: '2-\\5 -> 3',
    ref_only: true,
    type: :unused,
    type_summary: "op\\",
    impl: MacroImpl,
  ), create_op(
    name: "apply",
    sym: "@",
    desc: "increase precedence, apply next op before previous op",
    example: '2*3@+4 -> 14',
    type: {:unused => :unused},
    type_summary: "@op",
    impl_with_loc: ->from{raise ParseError.new("apply needs a right hand side if used on a binary op",from)}, # this can occur from something like 13@@
  ),
]
ActualOpsList = OpsList.reject{|o|String===o}

Ops0 = {}
Ops1 = {}
Ops2 = {}
AllOps = {}

def flipif(cond,impl)
  if cond
    -> a,b { impl[b,a] }
  else
    impl
  end
end

def addOp(table,op)
  if (existing=table[op.sym])
    combined_type = {}
    op.type.each{|s|combined_type[s.orig_key]=s.orig_val}
    existing.type.each{|s|combined_type[s.orig_key]=s.orig_val}
    combined_impl = -> arg_types,from {
      best_match = match_type(existing.type + op.type, arg_types)
      if existing.type.include? best_match
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

ActualOpsList.each{|op|
  next if op.ref_only
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
ImplicitOp = Ops2["build"]
AllOps[""]=Ops2[""]=ImplicitOp # allow @ to flip the implicit op (todo pointless for multiplication)
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

def create_num(str)
  create_op(
    name: "data",
    type: Num,
    impl: str[/[.e]/] ? str.to_f : str.to_i
  )
end

def create_str(str)
  raise LexError.new("unterminated string") if str[-1] != '"' || str.size==1
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

Commands = {
  "help" => ["see op's info", "op", -> tokens, last, context, saves {
    raise ParseError.new("usage: help <op>, see golfscript.com/atlas for tutorial",tokens[0]) if tokens.size != 2
    relevant = ActualOpsList.filter{|o|[o.name, o.sym].include?(tokens[0].str)}
    if !relevant.empty?
      relevant.each(&:help)
    else
      puts "no such op: #{tokens[0].str}"
    end
  }],
  "version" => ["see atlas version", nil, -> tokens, last, context, saves {
    raise ParseError.new("usage: version",tokens[0]) if tokens.size != 1
    puts $version
  }],
  "type" => ["see expression type", "a", -> tokens, last, context, saves {
    p infer(to_ir(tokens.size<2 ? last : parse_line(tokens, last),context,saves)).type_with_vec_level
  }],
  "p" => ["pretty print value", "a", -> tokens, last, context, saves {
    ast = tokens.size<2 ? last : parse_line(tokens, last)
    ir=infer(to_ir(ast,context,saves))
    run(ir) {|v,n,s| inspect_value(ir.type+ir.vec_level,v,ir.vec_level) }
    puts
  }],
  "print" => ["print value (implicit)", "a", -> tokens, last, context, saves {
    ast = tokens.size<2 ? last : parse_line(tokens, last)
    ir=infer(to_ir(ast,context,saves))
    run(ir) {|v,n,s| to_string(ir.type+ir.vec_level,v,false,n,s) }
  }],

}
