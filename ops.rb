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
    :min_zip_level, # only const uses it, todo remove probably
    :no_zip,
    :impl)
  def narg
    type ? type[0].specs.size : 0
  end
  def help
    puts "#{name} #{sym}"
    puts desc if desc
    type.each{|t|
      puts t.inspect.gsub('->','→').gsub('[Char]','Str')
    }
    examples.each{|example|
      puts example.gsub('->','→')
    }
    misc = []
    puts "no_zip=true" if no_zip
    puts "min_zip_level=#{min_zip_level}" if min_zip_level>0
    puts
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
  min_zip_level: 0,
  no_zip: false,
  poly_impl: nil, # impl that needs type info
  impl: nil,
  impl_with_loc: nil, # impl that could throw, needs token location for err msgs
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
  Op.new(name,sym,type,examples,desc,no_promote,min_zip_level,no_zip,built_impl)
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
    }}
  ), create_op(
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
    }}
  ), create_op(
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
    # Test: 3=2 -> []
    sym: "=",
    type: { [A,A] => [A] },
    poly_impl: -> ta,tb {-> a,b { spaceship(a,b,ta) == 0 ? [b,Null] : [] } }
  ), create_op(
    name: "lessThan",
    example: '4<5 -> [5]',
    # Test: 5<4 -> []
    sym: "<",
    type: { [A,A] => [A] },
    poly_impl: -> ta,tb {-> a,b { spaceship(a,b,ta) == -1 ? [b,Null] : [] } }
  ), create_op(
    name: "greaterThan",
    example: '5>4 -> [4]',
    # Test: 4>5 -> []
    sym: ">",
    type: { [A,A] => [A] },
    poly_impl: -> ta,tb {-> a,b { spaceship(a,b,ta) == 1 ? [b,Null] : [] } }
  ), create_op(
    name: "len",
    example: '"asdf"# -> 4',
    sym: "#",
    type: { [A] => Int },
    impl: -> a { len(a) }
  ), create_op(
    name: "const",
#     example: '"abcd" const "123"% -> "abcd"',
    type: { [A,B] => A },
    min_zip_level: 1,
    impl: -> a,b { a.value }
  ), create_op(
    name: "and",
    sym: "&",
    example: '1&2 -> 2',
    # Test: 0&2 -> 0
    type: { [A,B] => B },
    poly_impl: ->ta,tb { -> a,b { truthy(ta,a) ? b.value : tb.default_value }}
  ), create_op(
    name: "or",
    sym: "|",
    example: '1|2 -> 1',
    example2: '1|"b" -> "1"',
    example3: '"b"|3 -> "b"',
    # Test: 0|2 -> 2
    # Test: 0|"b" -> "0"
    # Test: ""|2 -> "2"
    # Test: 0|'c -> "c"
    # Test: (4 3)|"f" -> <"4","3">
    type: { [A,A] => A,
            [Aint,[Achar]] => [Achar],
            [[Achar],Aint] => [Achar] },
    poly_impl: ->ta,tb { -> a,b { truthy(ta,a) ? coerce(ta,a,tb) : coerce(tb,b,ta) }},
  ), create_op(
    name: "input",
    sym: "$",
    type: [Str],
    impl: -> { lines(ReadStdin) }
  ), create_op(
    name: "show",
    sym: "`",
    example: '12` -> "12"',
    type: { A => Str },
    # Test: "a"` -> "\"a\""
    # Test: 'a` -> "'a"
    # Test: 1;` -> "[1]"
    no_zip: true,
    poly_impl: -> t { -> a { inspect_value(t.type+t.vec_level,a,t.vec_level) } }
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
    # Test: "abc"[(2~) -> ""
    # Test: ""[2 -> ""
    type: { [[A],Int] => [A] },
    impl: -> a,b { take(b.value, a) }
  ), create_op(
    name: "drop",
    sym: "]",
    example: '"abcd"]3 -> "d"',
    # Test: "abc"](2~) -> "abc"
    # Test: ""]2 -> ""
    type: { [[A],Int] => [A] },
    impl: -> a,b { drop(b.value, a) }
  ), create_op(
    name: "range",
    example: '3 range 7 -> <3,4,5,6>',
    type: { [Int,Int] => VecOf.new(Int),
            [Char,Char] => VecOf.new(Char) },
    impl: -> a,b { range(a.value, b.value) }
  ), create_op(
    name: "concat",
    sym: "_",
    no_promote: true,
    example: '"abc"; "123"_ -> "abc123"',
    type: { [[A]] => [A] },
    impl: -> a { concat(a) },
  ), create_op(
    name: "implicit",
    sym: " ",
    example: '1+1 3 -> 6',
    example2: '1"a" -> "1a"',
    type: { [Int,Int] => Int,
            [Str,Str] => Str,
            [Str,Int] => Str,
            [Int,Str] => Str },
    poly_impl: -> ta,tb {
      if ta==Int && tb==Int
        -> a,b { a.value*b.value }
      else
        -> a,b {
          a = inspect_value(Int,a,0).const if ta == Int
          b = inspect_value(Int,b,0).const if tb == Int
          append(a,b)
        }
      end
    },
  ), create_op(
    name: "append",
    sym: "_",
    example: '"abc"_"123" -> "abc123"',
    type: { [[A],[A]] => [A] },
    impl: -> a,b { append(a,b) }
  ), create_op(
    name: "cons",
    sym: "`",
    example: '"abc"`\'d -> "dabc"',
    type: { [[A],A] => [A] },
    impl: -> a,b { [b,a] }
  ), create_op(
    name: "snoc",
    desc: "this op prefers to promote the 2nd arg once rather than vectorize it in order for inuitive list construction",
    sym: ",",
    example: '1,2,3 -> [1,2,3]',
    # Test: 2,1 -> [2,1]
    # Test: (2,3),1 -> [2,3,1]
    # Test: (2,3),(4,5),1 -> <[2,3,1],[4,5,1]>
    # Test: 2,(1,0) -> [[2],[1,0]]
    # Test: (2,3),(1,0) -> [[2,3],[1,0]]
    # Test: (2,3).,1 -> <[2,1],[3,1]>
    # Test: (2,3),(4,5).,1 -> <[2,3,1],[4,5,1]>
    # Test: 2,(1,0.) ->  <[2,1],[2,0]>
    # Test: (2,3),(1,0.) -> <[2,3,1],[2,3,0]>
    type: { [[A],A] => [A] },
    impl: -> a,b { append(a,[b,Null].const) }
  ), create_op(
    name: "transpose",
    sym: "\\",
    example: '"abc","123"\\ -> ["a1","b2","c3"]',
    # Test: "abc"; "1234"\ -> ["a1","b2","c3","4"]
    type: { [[A]] => [[A]] },
    impl: -> a { transpose(a) },
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
    # Test: "hi" type -> "[Char]"
    # Test: () type -> "Nil"
    type: { A => Str },
    no_zip: true,
    poly_impl: -> at { -> a { str_to_lazy_list(at.inspect) }},
  ), create_op(
    name: "version",
    type: Str,
    impl: -> { str_to_lazy_list("Atlas Alpha (Feb 27, 2023)") },
  ), create_op(
    name: "reductions",
    desc: "operation count so far",
    type: Int,
    impl: -> { $reductions },

  # Macros, type only used to specify number of args
  ), create_op(
    name: "let",
    example: '5:a+a -> 10',
    sym: ":",
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
  ),
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
        begin
          check_base_elem_constraints(fn_type.specs, arg_types)
        rescue AtlasTypeError
          false
        end
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
NilOp = AllOps['nil']
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
