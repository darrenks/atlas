require_relative "./type.rb"
require_relative "./escape.rb"
require_relative "./error.rb"
require_relative "./lazylib.rb"

class Op < Struct.new(
    :name,
    :sym, # optional
    :type,
    :poly_impl,
    :impl,
    :token,
    keyword_init: true)
  def initialize(args)
    if args[:type]
      args[:type] = case raw_spec = args[:type]
      when Hash
        raw_spec.map{|raw_arg,ret|
          specs = (x=case raw_arg
            when Array
              if raw_arg.size == 1
                [raw_arg]
              else
                raw_arg
              end
            else
              [raw_arg]
            end).map{|a_raw_arg| Op.parse_raw_arg_spec(a_raw_arg) }
          FnType.new(specs,ret)
        }
      when Type, Array
        [FnType.new([],raw_spec)]
      else
        raise "unknown fn type format"
      end
    end
    super(args)
  end

  def explicit_zip_level
    str[/^!*/].size
  end

  def self.parse_raw_arg_spec(raw,list_nest_depth=0)
    case raw
    when Symbol
      VarTypeSpec.new(raw,list_nest_depth)
    when Array
      raise if raw.size != 1
      Op.parse_raw_arg_spec(raw[0],list_nest_depth+1)
    when Type
      ExactTypeSpec.new(raw.dim+list_nest_depth, raw)
    when TypeSpec
      raw
    else
      p raw
      error
    end
  end

  def narg
    type[0].specs.size
  end
  def nret
    sym=="O" ? 0 : 1 # todo...
  end

  def str
    token.str
  end
  def get_impl(arg_types)
    ans = if impl != nil
      impl
    elsif poly_impl != nil
      poly_impl[*arg_types]
    else
      raise "ops must specify impl or poly_impl"
    end
    return ans if Proc === ans
    return lambda{ ans }
  end
end

OpsList = [
  Op.new(
    name: "cons",
    sym: ":",
    # Example: : 'a "bc" -> "abc"
    # Test: :1 $ -> [1]
    # todo
    ## Test: :$ $ -> [1]
    type: { [A,[A]] => [A] },
    impl: -> a,b { [a,b] },
  ),
  Op.new(
    name: "head",
    sym: "[",
    # Example: [ "abc" -> 'a
    type: { [A] => A },
    impl: -> a {
      raise DynamicError.new "head on empty list",nil if a.value==[]
      a.value[0].value
    }
  ), Op.new(
    name: "last",
    sym: "]",
    # Example: ] "abc" -> 'c
    type: { [A] => A },
    impl: -> a {
      raise DynamicError.new "last on empty list",nil if a.value==[]
      last(a.value, nil ) # todo for errors
    }
  ), Op.new(
    name: "tail",
    # Example: ) "abc" -> "bc"
    sym: ")",
    type: { [A] => [A] },
    impl: -> a {
      raise DynamicError.new "tail on empty list",nil if a.value==[]
      a.value[1].value}
  ), Op.new(
    name: "init",
    # Example: ( "abc" -> "ab"
    sym: "(",
    type: { [A] => [A] },
    impl: -> a {
      raise DynamicError.new "init on empty list",nil if a.value==[]
      init(a.value,nil)
    } #todo from
  ), Op.new(
    name: "add",
    sym: "+",
    # Example: +1 2 -> 3
    type: { [Int,Int] => Int,
            [Int,Char] => Char,
            [Char,Int] => Char },
    impl: -> a,b { a.value + b.value }
  ), Op.new(
    name: "sub",
    sym: "-",
    # Example: -5 3 -> 2
    type: { [Int,Int] => Int,
            [Char,Int] => Char,
            [Char,Char] => Int },
    impl: -> a,b { a.value - b.value }
  ), Op.new(
    name: "mult",
    # Example: *2 3 -> 6
    sym: "*",
    type: { [Int,Int] => Int },
    impl: -> a,b { a.value * b.value }
  ), Op.new(
    name: "div",
    # Example: /7 3 -> 2
    sym: "/",
    type: { [Int,Int] => Int },
    impl: -> a,b {
      if b.value==0
        raise DynamicError.new("div 0",nil) # todo maybe too complicated to be worth it same for mod
      else
        a.value/b.value
      end
    }
  ), Op.new(
    name: "mod",
    # Example: %7 3 -> 1
    sym: "%",
    type: { [Int,Int] => Int },
    impl: -> a,b {
      if b.value==0
        raise DynamicError.new("mod 0",nil)
      else
        a.value % b.value
      end
    }
  ), Op.new(
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
  ), Op.new(
    name: "rep",
    sym: ",",
    # Example: ,2 -> [2,2,2,2,2...
    type: { A => [A] },
    impl: -> a { repeat(a) }
  ), Op.new(
    name: "eq",
    # Example: eq 3 3 -> 1
    # Test: eq 3 2 -> 0
    sym: "=",
    type: { [A,A] => Int },
    poly_impl: -> ta,tb {-> a,b { equal(a.value,b.value,ta) ? 1 : 0 } }
  ), Op.new(
    name: "nil",
    # Example: $ -> []
    sym: "$",
    type: Nil,
    impl: -> { [] }
  ), Op.new(
    name: "pad",
    # Example: |"abc" '_ -> "abc_____...
    sym: "|",
    type: { [[A],A] => [A] },
    impl: -> a,b { pad(a,b) }
  ), Op.new(
    name: "const",
    sym: "&",
    # Example: & "abcd" "123" -> "abc"
    type: { [[A],[B]] => [A],
            [A,B] => [A] },
    poly_impl: ->ta,tb { raise AtlasTypeError.new("asdf",nil) if tb.dim == 0
        -> a,b { zipn(1,[ta.dim==0 ? Promise.new{repeat(a)} : a,b],->aa,bb{aa.value}) }
      }
  ), Op.new(
    name: "if",
    sym: "?",
    # Example: ? 1 "yes" "no" -> "yes"
    type: { [A,B,B] => B },
    poly_impl: -> ta,tb,tc {
      if ta == Int
        # Test: !? :~1;2 1 0 -> [0,1]
        lambda{|a,b,c| a.value > 0 ? b.value : c.value }
      elsif ta == Char
        # Test: !? " d" 1 0 -> [0,1]
        lambda{|a,b,c| a.value.chr[/\S/] ? b.value : c.value }
      else # List
        # Test: !? :"" ;"a" 1 0 -> [0,1]
        lambda{|a,b,c| a.value != [] ? b.value : c.value }
      end
    }
  ), Op.new(
    # Hidden
    name: "output",
    sym: "O",
    type: { A => Int }, # lies for single output
    poly_impl: -> t { -> a { print_value(t,a.value,t) }}
  ), Op.new(
    # Hidden
    name: "input",
    sym: "I",
    type: Str,
    impl: -> { ReadStdin.value }
  ), Op.new(
    # Hidden
    name: "input2",
    sym: "zI",
    type: [Str],
    impl: -> { lines(ReadStdin.value) }
  ), Op.new(
    name: "show",
    sym: "`",
    # Example: `12 -> "12"
    type: { A => Str },
    # Test: `"a" -> "\"a\""
    # Test: `'a -> "'a"
    # Test: `;1 -> "[1]"
    poly_impl: -> t { -> a { inspect_value(t,a.value) } }
  ), Op.new(
    name: "single",
    sym: ";",
    # Example: ; 2 -> [2]
    type: { A => [A] },
    impl: -> a { [a,Null] }
  ), Op.new(
    name: "take",
    sym: "{",
    # Example: { 3 "abcd" -> "abc"
    # Test: { ~2 "abc" -> ""
    # Test: { 2 "" -> ""
    type: { [Int,[A]] => [A] },
    impl: -> a,b { take(a.value, b) }
  ), Op.new(
    name: "drop",
    sym: "}",
    # Example: } 3 "abcd" -> "d"
    # Test: } ~2 "abc" -> "abc"
    # Test: } 2 "" -> ""
    type: { [Int,[A]] => [A] },
    impl: -> a,b { drop(a.value, b) }
  ), Op.new(
    name: "concat",
    sym: "_",
    # Example: _:"abc";"123" -> "abc123"
    type: { [[A]] => [A] },
    impl: -> a { concat_map(a.value,[]){|i,r,first|append(i,r)} },
  ), Op.new(
    name: "append",
    sym: "@",
    # Example: @"abc" "123" -> "abc123"
    type: { [[A],[A]] => [A] },
    impl: -> a,b { append(a.value,b) },
  ), Op.new(
    name: "transpose",
    sym: "\\",
    # Example: \:"abc";"123" -> ["a1","b2","c3"]
    # Test: \:"abc";"1234" -> ["a1","b2","c3","4"]
    type: { [[A]] => [[A]] },
    impl: -> a { transpose(a.value) },
  )
]

Ops = {}; OpsList.each{|op|
  Ops[op.name] = Ops[op.sym] = op
}
RepOp = Ops["rep"]

def create_int(str)
  Op.new(
    sym: str,
    name: str,
    type: Int,
    impl: str.to_i
  )
end

def create_str(str)
  Op.new(
    sym: str,
    name: str,
    type: Str,
    impl: str_to_lazy_list(parse_str(str[1...-1]))
  )
end

def create_char(str)
  Op.new(
    sym: str,
    name: str,
    type: Char,
    impl: parse_char(str[1..-1]).ord
  )
end