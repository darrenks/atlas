# todo some ops may only error because return type if using head, but no other ops like it

tests = <<'EOF'
## 1 arg #######

# A (inspect)
`1 -> ` 1
`;1 -> ` ; 1
`;;1 -> ` ; ; 1

# scalar (negate)
~ 1 -> ~ 1
~ ;1 -> !~ ; 1
~ ;;1 -> !!~ ; ; 1

# [scalar] (read)
~ 'c -> AtlasTypeError
~ "c" -> ~ "c"
~ ;"c" -> !~ ; "c"

# [A] (head)
[ 1 -> AtlasTypeError
[ ; 1 -> [ ; 1
[ ; ; 1 -> [ ; ; 1

# [[A]] (transpose)
\\ 1 -> AtlasTypeError
\ ; 1 -> AtlasTypeError
\ ; ; 1 -> \ ; ; 1

## 2 arg #########
# A,A (eq)
eq 1 1 -> = 1 1
eq 1 ;1 -> != , 1 ; 1
eq 1 ;;1 -> !!= , , 1 ; ; 1
eq ;1 1 -> != ; 1 , 1
eq ;1 ;1 -> = ; 1 ; 1
eq ;1 ;;1 -> != , ; 1 ; ; 1
eq ;;1 1 -> !!= ; ; 1 , , 1
eq ;;1 ;1 -> != ; ; 1 , ; 1
eq ;;1 ;;1 -> = ; ; 1 ; ; 1

# A,[A] (cons)
: 1 1 -> AtlasTypeError
: 1 ;1 -> : 1 ; 1
: 1 ;;1 -> !: , 1 ; ; 1
: ;1 1 -> AtlasTypeError
: ;1 ;1 -> !: ; 1 , ; 1
: ;1 ;;1 -> : ; 1 ; ; 1

# [A],[A] (append todo)

# scalar scalar (add)
+ 1 2 -> + 1 2
+ ;1 2 -> !+ ; 1 , 2
+ 1 ;2 -> !+ , 1 ; 2

# Int,[A] (take)
{ 1 1 -> AtlasTypeError
{ 1 ;1 ->{ 1 ; 1
{ 1 ;;1 ->{ 1 ; ; 1
{ ;1 1 -> AtlasTypeError
{ ;1 ;1 -> !{ ; 1 , ; 1
{ ;1 ;;1 -> !{ ; 1 ; ; 1

## 3 arg ###########
# A,B,B
? 1 2 3 -> ? 1 2 3
? 1 2 ;3 -> !? , 1 , 2 ; 3
? 1 2 ;;3 -> !!? , , 1 , , 2 ; ; 3
? 1 ;2 3 -> !? , 1 ; 2 , 3
? 1 ;2 ;3 -> ? 1 ; 2 ; 3
? 1 ;2 ;;3 -> !? , 1 , ; 2 ; ; 3
? 1 ;;2 3 -> !!? , , 1 ; ; 2 , , 3
? 1 ;;2 ;3 -> !? , 1 ; ; 2 , ; 3
? 1 ;;2 ;;3 -> ? 1 ; ; 2 ; ; 3

? ;1 2 3 -> ? ; 1 2 3
? ;1 2 ;3 -> !? ; 1 , 2 ; 3
? ;1 2 ;;3 -> !!? , ; 1 , , 2 ; ; 3
? ;1 ;2 3 -> !? ; 1 ; 2 , 3
? ;1 ;2 ;3 -> ? ; 1 ; 2 ; 3
? ;1 ;2 ;;3 -> !? ; 1 , ; 2 ; ; 3
? ;1 ;;2 3 -> !!? , ; 1 ; ; 2 , , 3
? ;1 ;;2 ;3 -> !? ; 1 ; ; 2 , ; 3
? ;1 ;;2 ;;3 -> ? ; 1 ; ; 2 ; ; 3

? ;;1 2 3 -> ? ; ; 1 2 3
? ;;1 2 ;3 -> !? ; ; 1 , 2 ; 3
? ;;1 2 ;;3 -> !!? ; ; 1 , , 2 ; ; 3
? ;;1 ;2 3 -> !? ; ; 1 ; 2 , 3
? ;;1 ;2 ;3 -> ? ; ; 1 ; 2 ; 3
? ;;1 ;2 ;;3 -> !? ; ; 1 , ; 2 ; ; 3
? ;;1 ;;2 3 -> !!? ; ; 1 ; ; 2 , , 3
? ;;1 ;;2 ;3 -> !? ; ; 1 ; ; 2 , ; 3
? ;;1 ;;2 ;;3 -> ? ; ; 1 ; ; 2 ; ; 3

### Nil tests #####

# A (inspect)
`$ -> ` $
`; $ -> ` ; $

# scalar (negate)
~$ -> AtlasTypeError
~;$ -> AtlasTypeError

# [scalar] none

# [A] (head)
[$ -> [ $
[;$ -> [ ; $

# [[A]] (concat)
# _$ -> AtlasTypeError todo
_;$ -> _ ; $
_;;$ -> _ ; ; $

## 2 arg #########
# A,A (eq)
eq $ 1 -> != $ , 1
eq $ ;1 -> = $ ; 1
eq $ ;;1 -> = $ ; ; 1
eq ;$ 1 -> !!= ; $ , , 1
eq ;$ ;1 -> != ; $ , ; 1
eq ;$ ;;1 -> = ; $ ; ; 1
eq ;;$ 1 -> !!!= ; ; $ , , , 1
eq ;;$ ;1 -> !!= ; ; $ , , ; 1
eq ;;$ ;;1 -> != ; ; $ , ; ; 1


# A,[A] (cons)

# [A],[A] (append todo)

# scalar scalar (add)
+$ 1 -> AtlasTypeError
+;$ 1 -> AtlasTypeError
+$ ;1 -> AtlasTypeError

# Int,[A] (take)
# todo, some should probably be no nil error
{1 $ -> { 1 $
{1 ;$ -> { 1 ; $
{1 ;;$ -> { 1 ; ; $
{;1 $ -> !{ ; 1 $
{;1 ;$ -> !{ ; 1 ; $
{;1 ;;$ -> !{ ; 1 ; ; $

{$ ;1 -> AtlasTypeError
{$ ;;1 -> AtlasTypeError
{$ $ -> AtlasTypeError

## 3 arg ###########
# A,B,B
? $ 2 3 -> ? $ 2 3
? $ 2 ;3 -> !? $ , 2 ; 3
? ;$ 2 3 -> ? ; $ 2 3
? $ ;2 ;3 -> ? $ ; 2 ; 3
? 1 $ 3 -> !? , 1 $ , 3
? 1 $ ;3 -> ? 1 $ ; 3
? 1 ;$ 3 -> !!? , , 1 ; $ , , 3
? 1 ;$ ;3 -> !? , 1 ; $ , ; 3
? 1 $ $ -> ? 1 $ $
? 1 $ ;$ -> ? 1 $ ; $
? 1 !$ ;$ -> ? 1 !$ ; $

### Excessive zip tests
## not excessive
# this actually could be useful
!$ -> !$
!`"1" -> !` "1"
!eq ;1 ;1 -> != ; 1 ; 1
!? ;1 ;2 ;3 -> !? ; 1 ; 2 ; 3

## excessive
!3 -> ParseError
!"" -> ParseError
! -> ParseError
!`1 -> AtlasTypeError
!["a" -> AtlasTypeError
!+1 2 -> AtlasTypeError
!{1 ;1 -> AtlasTypeError
!eq 1 1 -> AtlasTypeError
!eq 1 ;1 -> AtlasTypeError
!eq 1 ;1 -> AtlasTypeError
!!eq ;1 ;1 -> AtlasTypeError
!? 1 2 3 -> AtlasTypeError
!? ;1 2 ;3 -> AtlasTypeError

EOF

require "./ops.rb"
require "./lex.rb"
require "./parse.rb"
require "./type.rb"
require "./infer.rb"
require "./lazylib.rb"
require "./to1d.rb"

def doit(source)
  tokens = lex(source)
  root = parse(tokens)
  infer(root)
  to1d(root)[0]*" "
end

pass = 0
tests.lines.each{|test|
  next if test.strip == "" || test =~ /^\#/
  i,o=test.split("->")
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
