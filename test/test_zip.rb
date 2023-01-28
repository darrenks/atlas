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

// [A],a (pad)
1|1 -> 1;|1
1;|1 -> 1;|1
1;;|1 -> 1;;!|(1,)
1|(1;) -> 1;,!|(1;)
1;|(1;) -> 1;,!|(1;)
1;;|(1;) -> 1;;|(1;)

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

// 3 arg ////////////////
// A,B,B
1 then 2 else 3 -> 1 then 2 else 3
1 then 2 else (3;) -> 1,!then 2, else (3;)
1 then 2 else (3;;) -> 1,,!!then 2,, else (3;;)
1 then 2; else 3 -> 1,!then 2; else (3,)
1 then 2; else (3;) -> 1 then 2; else (3;)
1 then 2; else (3;;) -> 1,!then 2;, else (3;;)
1 then 2;; else 3 -> 1,,!!then 2;; else (3,,)
1 then 2;; else (3;) -> 1,!then 2;; else (3;,)
1 then 2;; else (3;;) -> 1 then 2;; else (3;;)

1; then 2 else 3 -> 1; then 2 else 3
1; then 2 else (3;) -> 1;!then 2, else (3;)
1; then 2 else (3;;) -> 1;,!!then 2,, else (3;;)
1; then 2; else 3 -> 1;!then 2; else (3,)
1; then 2; else (3;) -> 1; then 2; else (3;)
1; then 2; else (3;;) -> 1;!then 2;, else (3;;)
1; then 2;; else 3 -> 1;,!!then 2;; else (3,,)
1; then 2;; else (3;) -> 1;!then 2;; else (3;,)
1; then 2;; else (3;;) -> 1; then 2;; else (3;;)

1;; then 2 else 3 -> 1;; then 2 else 3
1;; then 2 else (3;) -> 1;;!then 2, else (3;)
1;; then 2 else (3;;) -> 1;;!!then 2,, else (3;;)
1;; then 2; else 3 -> 1;;!then 2; else (3,)
1;; then 2; else (3;) -> 1;; then 2; else (3;)
1;; then 2; else (3;;) -> 1;;!then 2;, else (3;;)
1;; then 2;; else 3 -> 1;;!!then 2;; else (3,,)
1;; then 2;; else (3;) -> 1;;!then 2;; else (3;,)
1;; then 2;; else (3;;) -> 1;; then 2;; else (3;;)

1 !then 2 else 3 -> AtlasTypeError
1; !then 2 else (3;) -> AtlasTypeError

/// Nil tests ////////

// A (inspect)
$` -> $`
$;` -> $;`

// scalar (negate)
$~ -> AtlasTypeError
$;~ -> AtlasTypeError

// [scalar] none

// [A] (head)
$[ -> $[
$;[ -> $;[

// [[A]] (concat)
$_ -> $_
$;_ -> $;_
$;;_ -> $;;_

// 2 arg /////////
// A,A (eq)
$=1 -> $!=(1,)
$=(1;) -> $=(1;)
$=(1;;) -> $=(1;;)
$;=1 -> $;!!=(1,,)
$;=(1;) -> $;!=(1;,)
$;=(1;;) -> $;=(1;;)
$;;=1 -> $;;!!!=(1,,,)
$;;=(1;) -> $;;!!=(1;,,)
$;;=(1;;) -> $;;!=(1;;,)


// [A],A (pad)
$|1 -> $|1
$|(1;) -> $|(1;)
$;|1 -> $;!|(1,)
// todo this is zipping into nil, should be error?
1|$ -> 1;,!|$
1;;|$ -> 1;;|$

// [A],[A] (append)
1 $ -> 1;‿$

// scalar scalar (add)
$+1 -> AtlasTypeError
$;+1 -> AtlasTypeError
$+(1;) -> AtlasTypeError

// Int,[A] (take)
// todo, some should probably be no nil error
$[1 -> $[1
$;[1 -> $;[1
$;;[1 -> $;;[1
$[(1;) -> $,![(1;)
$;[(1;) -> $;![(1;)
$;;[(1;) -> $;;![(1;)

1;[$ -> AtlasTypeError
1;;[$ -> AtlasTypeError
$[$ -> AtlasTypeError

// 3 arg //////////
// A,B,B
$ then 2 else 3 -> $ then 2 else 3
$ then 2 else (3;) -> $!then 2, else (3;)
$; then 2 else 3 -> $; then 2 else 3
$ then 2; else (3;) -> $ then 2; else (3;)
1 then $ else 3 -> 1,!then $ else (3,)
1 then $ else (3;) -> 1 then $ else (3;)
1 then $; else 3 -> 1,,!!then $; else (3,,)
1 then $; else (3;) -> 1,!then $; else (3;,)
1 then $ else $ -> 1 then $ else $
1 then $ else ($;) -> 1 then $ else ($;)
1 then !$ else ($;) -> 1 then !$ else ($;)

/// Excessive zip tests
// not excessive
// this actually could be useful
!$ -> !$
"1"!` -> "1"!`
1;!=(1;) -> 1;!=(1;)
1; then 2; else (3;) -> 1; then 2; else (3;)

EOF

require "./ops.rb"
require "./test/run_lines.rb"

# There are no ops of type [a] that allow promote, make one for testing
Ops1[']'].promote=ALLOW_PROMOTE

run_tests(tests) { |source|
  tokens = lex(source)
  context={}
  root = parse_line(tokens,context)
  replace_vars(root,context)
  infer(root)
  to_infix(root)
}
