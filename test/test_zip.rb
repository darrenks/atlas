tests = <<'EOF'
// 1 arg ////////

// A (inspect)
`1 -> `1
`;1 -> `;1
`;;1 -> `;;1
!`1 -> AtlasTypeError
!`;1 -> !`;1

// scalar (negate)
~1 -> ~1
~;1 -> !~;1
~;;1 -> !!~;;1
!~1 -> AtlasTypeError
!~;1 -> AtlasTypeError

// [scalar] (read)
~'c -> ~;'c
~"c" -> ~"c"
~;"c" -> !~;"c"
!~"c" -> !~!;"c"
!~;"c" -> !!~!!;;"c"
!!~"c" -> AtlasTypeError
!!~;;"c" -> AtlasTypeError

// [A] (head)
[1 -> AtlasTypeError
[;1 -> [;1
[;;1 -> [;;1
![;1 -> AtlasTypeError
![;;1 -> ![;;1

]1 -> ];1
!]1 -> AtlasTypeError
!];1 -> !]!;;1

// [[A]] (transpose)
\1 -> \;;1
\;1 -> \;;1
\;;1 -> \;;1
!\1 -> AtlasTypeError
!\;1 -> !\!;!;;1
!\;;1 -> !\!;;;1

// 2 arg ///////////
// A,A (eq)
1==1 -> 1==1
1==;1 -> (,1)!==;1
1==;;1 -> (,,1)!!==;;1
(;1)==1 -> (;1)!==,1
(;1)==;1 -> (;1)==;1
(;1)==;;1 -> (,;1)!==;;1
(;;1)==1 -> (;;1)!!==,,1
(;;1)==;1 -> (;;1)!==,;1
(;;1)==;;1 -> (;;1)==;;1
(;1)!==;;1 -> (,;1)!!==;;1
1!==1 -> AtlasTypeError
1!==;1 -> AtlasTypeError
1!==;1 -> AtlasTypeError
;1!!==;1 -> AtlasTypeError

// A,[A] (cons)
1:1 -> 1:;1
1:;1 -> 1:;1
1:;;1 -> (,1)!:;;1
(;1):1 -> (;1)!:,;1
(;1):;1 -> (;1)!:,;1
(;1):;;1 -> (;1):;;1

// [A],[A] (append)
1@1 -> (;1)@;1
1@;1 -> (;1)@;1
(;1)@1 -> (;1)@;1
(;1)@(;;1) -> (,;1)!@;;1
1@;;1 -> (,;1)!@;;1

1!@1 -> AtlasTypeError
(;1)@;;1 -> (,;1)!@;;1
(;1)!@;1 -> AtlasTypeError
(;;1)!@(;;1) -> (;;1)!@;;1

// scalar scalar (add)
1+2 -> 1+2
(;1)+2 -> (;1)!+,2
1+;2 -> (,1)!+;2
1!+2 -> AtlasTypeError

// Int,[A] (take)
1[1 -> 1[;1
1[;1 -> 1[;1
1[;;1 -> 1[;;1
(;1)[1 -> (;1)![,;1
(;1)[;1 -> (;1)![,;1
(;1)[;;1 -> (;1)![;;1
1![;1 -> AtlasTypeError

// [a] [a] must promote
1 2 -> (;1)@;2
1(;2) -> (;1)@;2
(;1) 2 -> (;1)@;2
;1(;2) -> ;(;1)@;2
1 ;1 -> (;1)@;1
1(;;1) -> (;;1)@;;1
(;1)! ;1 -> (!;;1)!@!;;1
1! ;1 -> (,;1)!@!;;1
1! 2 -> AtlasTypeError

// 3 arg ////////////////
// A,B,B
if 1 then 2 else 3 -> if 1 then 2 else 3
if 1 then 2 else ;3 -> !if ,1 then ,2 else ;3
if 1 then 2 else ;;3 -> !!if ,,1 then ,,2 else ;;3
if 1 then ;2 else 3 -> !if ,1 then ;2 else ,3
if 1 then ;2 else ;3 -> if 1 then ;2 else ;3
if 1 then ;2 else ;;3 -> !if ,1 then ,;2 else ;;3
if 1 then ;;2 else 3 -> !!if ,,1 then ;;2 else ,,3
if 1 then ;;2 else ;3 -> !if ,1 then ;;2 else ,;3
if 1 then ;;2 else ;;3 -> if 1 then ;;2 else ;;3

if ;1 then 2 else 3 -> if ;1 then 2 else 3
if ;1 then 2 else ;3 -> !if ;1 then ,2 else ;3
if ;1 then 2 else ;;3 -> !!if ,;1 then ,,2 else ;;3
if ;1 then ;2 else 3 -> !if ;1 then ;2 else ,3
if ;1 then ;2 else ;3 -> if ;1 then ;2 else ;3
if ;1 then ;2 else ;;3 -> !if ;1 then ,;2 else ;;3
if ;1 then ;;2 else 3 -> !!if ,;1 then ;;2 else ,,3
if ;1 then ;;2 else ;3 -> !if ;1 then ;;2 else ,;3
if ;1 then ;;2 else ;;3 -> if ;1 then ;;2 else ;;3

if ;;1 then 2 else 3 -> if ;;1 then 2 else 3
if ;;1 then 2 else ;3 -> !if ;;1 then ,2 else ;3
if ;;1 then 2 else ;;3 -> !!if ;;1 then ,,2 else ;;3
if ;;1 then ;2 else 3 -> !if ;;1 then ;2 else ,3
if ;;1 then ;2 else ;3 -> if ;;1 then ;2 else ;3
if ;;1 then ;2 else ;;3 -> !if ;;1 then ,;2 else ;;3
if ;;1 then ;;2 else 3 -> !!if ;;1 then ;;2 else ,,3
if ;;1 then ;;2 else ;3 -> !if ;;1 then ;;2 else ,;3
if ;;1 then ;;2 else ;;3 -> if ;;1 then ;;2 else ;;3

!if 1 then 2 else 3 -> AtlasTypeError
!if ;1 then 2 else ;3 -> AtlasTypeError

/// Nil tests ////////

// A (inspect)
`$ -> `$
`;$ -> `;$

// scalar (negate)
~$ -> AtlasTypeError
~;$ -> AtlasTypeError

// [scalar] none

// [A] (head)
[$ -> [$
[;$ -> [;$

// [[A]] (concat)
_$ -> _$
_;$ -> _;$
_;;$ -> _;;$

// 2 arg /////////
// A,A (eq)
$==1 -> $!==,1
$==;1 -> $==;1
$==;;1 -> $==;;1
(;$)==1 -> (;$)!!==,,1
(;$)==;1 -> (;$)!==,;1
(;$)==;;1 -> (;$)==;;1
(;;$)==1 -> (;;$)!!!==,,,1
(;;$)==;1 -> (;;$)!!==,,;1
(;;$)==;;1 -> (;;$)!==,;;1


// A,[A] (cons)
// : todo or remove

// [A],[A] (append)
1@$ -> (;1)@$

// scalar scalar (add)
$+1 -> AtlasTypeError
(;$)+1 -> AtlasTypeError
$+;1 -> AtlasTypeError

// Int,[A] (take)
// todo, some should probably be no nil error
1[$ -> 1[$
1[;$ -> 1[;$
1[;;$ -> 1[;;$
(;1)[$ -> (;1)![,$
(;1)[;$ -> (;1)![;$
(;1)[;;$ -> (;1)![;;$

$[;1 -> AtlasTypeError
$[;;1 -> AtlasTypeError
$[$ -> AtlasTypeError

// [A],[A] Must promote
$ $ -> (;$)@;$

// 3 arg //////////
// A,B,B
if $ then 2 else 3 -> if $ then 2 else 3
if $ then 2 else ;3 -> !if $ then ,2 else ;3
if ;$ then 2 else 3 -> if ;$ then 2 else 3
if $ then ;2 else ;3 -> if $ then ;2 else ;3
if 1 then $ else 3 -> !if ,1 then $ else ,3
if 1 then $ else ;3 -> if 1 then $ else ;3
if 1 then ;$ else 3 -> !!if ,,1 then ;$ else ,,3
if 1 then ;$ else ;3 -> !if ,1 then ;$ else ,;3
if 1 then $ else $ -> if 1 then $ else $
if 1 then $ else ;$ -> if 1 then $ else ;$
if 1 then !$ else ;$ -> if 1 then !$ else ;$

/// Excessive zip tests
// not excessive
// this actually could be useful
!$ -> !$
!`"1" -> !`"1"
(;1)!==;1 -> (;1)!==;1
!if ;1 then ;2 else ;3 -> !if ;1 then ;2 else ;3

// excessive
!3 -> ParseError
// !"" -> ParseError # todo better error
! -> ParseError

EOF

require "./ops.rb"
require "./lex.rb"
require "./parse.rb"
require "./type.rb"
require "./infer.rb"
require "./lazylib.rb"
require "./to_infix.rb"

# There are no ops of type [a] that allow promote, make one for testing
Ops1[']'].promote=ALLOW_PROMOTE

def doit(source)
  tokens = lex(source)
  context={}
  root = parse_line(tokens,context)
  replace_vars(root,context)
  infer(root)
  to_infix(root)
end

pass = 0
tests.lines.each{|test|
  next if test.strip == "" || test =~ /^\/\//
  i,o=test.split("-"+">")
  STDERR.puts "INVALID test #{test}" if !o
  o.strip!
  expected = o

  begin
    found = doit(i)
  rescue Exception
    found = $!
  end

  if o=~/Error/ ? found.class.to_s!=o : found != expected
    STDERR.puts "FAIL: zip test"
    STDERR.puts i
    STDERR.puts "expected:"
    STDERR.puts expected
    STDERR.puts "found:"
    STDERR.puts found
    exit(1)
  end

  pass += 1
}

puts "PASS %d zip tests" % pass
