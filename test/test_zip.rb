# Test that inference chooses correct zip level and promotes and replicates
tests = <<'EOF'
// 1 arg ////////

// A (inspect)
1` -> 1`
1;` -> 1;`
1;;` -> 1;;`
1!` -> AtlasTypeError
1;!` -> 1;!`

// scalar (negate)
1~ -> 1~
1;~ -> 1;!~
1;;~ -> 1;;!!~
1!~ -> AtlasTypeError
1;!~ -> AtlasTypeError

// [scalar] (read)
'c~ -> 'c;~
"c"~ -> "c"~
"c";~ -> "c";!~
"c"!~ -> "c"!;!~
"c";!~ -> "c";!!;!!~
"c"!!~ -> AtlasTypeError
"c";;!!~ -> AtlasTypeError

// [A] (head)
1[ -> AtlasTypeError
1;[ -> 1;[
1;;[ -> 1;;[
1;![ -> AtlasTypeError
1;;![ -> 1;;![

// [A] but promote allowed
1] -> 1;]
1!] -> AtlasTypeError
1;!] -> 1;!;!]

// [[A]] (transpose)
1\ -> 1;;\
1;\ -> 1;;\
1;;\ -> 1;;\
1!\ -> AtlasTypeError
1;!\ -> 1;!;!;!\
1;;!\ -> 1;;!;!\

// 2 arg ///////////
// A,A (eq)
1=1 -> 1=1
1=(1;) -> 1,!=(1;)
1=(1;;) -> 1,,!!=(1;;)
1;=1 -> 1;!=(1,)
1;=(1;) -> 1;=(1;)
1;=(1;;) -> 1;,!=(1;;)
1;;=1 -> 1;;!!=(1,,)
1;;=(1;) -> 1;;!=(1;,)
1;;=(1;;) -> 1;;=(1;;)
1;!=(1;;) -> 1;,!!=(1;;)
1!=1 -> AtlasTypeError
1!=(1;) -> AtlasTypeError
1;!!=(1;) -> AtlasTypeError

// A,A promote second preferred
"as " | 'b -> "as "|('b;)
'a | "as" -> 'a,!|"as"

// [A],a (none for now, add test back when said op type exists again todo)
// 1 pad 1 -> 1; pad 1
// 1; pad 1 -> 1; pad 1
// 1;; pad 1 -> 1;;!pad (1,)
// 1 pad (1;) -> 1;,!pad (1;)
// 1; pad (1;) -> 1;,!pad (1;)
// 1;; pad (1;) -> 1;; pad (1;)

// [A],[A] (append, promote preferred)
1 1 -> 1;‿(1;)
1 (1;) -> 1;‿(1;)
1; 1 -> 1;‿(1;)
1; (1;;) -> 1;;‿(1;;)
1 (1;;) -> 1;;‿(1;;)

1! 1 -> AtlasTypeError
1;! (1;) -> 1;!;!‿(1;!;)
1;;! (1;;) -> 1;;!‿(1;;)

// scalar scalar (add)
1+2 -> 1+2
1;+2 -> 1;!+(2,)
1+(2;) -> 1,!+(2;)
1!+2 -> AtlasTypeError

// [A],Int (take)
1[1 -> 1;[1
1;[1 -> 1;[1
1;;[1 -> 1;;[1
1[(1;) -> 1;,![(1;)
1;[(1;) -> 1;,![(1;)
1;;[(1;) -> 1;;![(1;)
1;![1 -> AtlasTypeError

// todo test A,[B] and A,B more?

/// Nil tests ////////

// A (inspect)
()` -> nil`
();` -> nil;`

// scalar (negate)
()~ -> AtlasTypeError
();~ -> AtlasTypeError

// [scalar] none

// [A] (head)
()[ -> nil[
();[ -> nil;[

// [[A]] (concat)
()_ -> nil_
();_ -> nil;_
();;_ -> nil;;_

// 2 arg /////////
// A,A (eq)
()=1 -> nil!=(1,)
()=(1;) -> nil=(1;)
()=(1;;) -> nil=(1;;)
();=1 -> nil;!!=(1,,)
();=(1;) -> nil;!=(1;,)
();=(1;;) -> nil;=(1;;)
();;=1 -> nil;;!!!=(1,,,)
();;=(1;) -> nil;;!!=(1;,,)
();;=(1;;) -> nil;;!=(1;;,)


// [A],A (pad) todo no such op
// () pad 1 -> nil pad 1
// () pad (1;) -> nil pad (1;)
// (); pad 1 -> nil;!pad (1,)
// // todo this is zipping into nil, should be error?
// 1 pad () -> 1;,!pad nil
// 1;; pad () -> 1;; pad nil

// [A],[A] (append)
1 () -> 1;‿nil

// scalar scalar (add)
()+1 -> AtlasTypeError
();+1 -> AtlasTypeError
()+(1;) -> AtlasTypeError

// Int,[A] (take)
// todo, some should probably be no nil error
()[1 -> nil[1
();[1 -> nil;[1
();;[1 -> nil;;[1
()[(1;) -> nil,![(1;)
();[(1;) -> nil;![(1;)
();;[(1;) -> nil;;![(1;)

1;[() -> AtlasTypeError
1;;[() -> AtlasTypeError
()[() -> AtlasTypeError

/// Excessive zip tests
// not excessive
// this actually could be useful
!nil -> !nil
"1"!` -> "1"!`
1;!=(1;) -> 1;!=(1;)

EOF

require "./ops.rb"
require "./test/run_lines.rb"

# There are no ops of type [a] that allow promote, make one for testing
Ops1[']'].promote=ALLOW_PROMOTE

run_tests(tests) { |source|
  tokens,lines = lex(source)
  root = parse_line(tokens[0])
  ir = to_ir(root, {})
  infer(ir)
  ir.to_infix
}
