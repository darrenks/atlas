# Test that parse generates the correct AST
tests = <<'EOF'
1+2 -> 1+2
1+2*3 -> 1+2*3
1+(2*3) -> 1+(2*3)
1~+2*3 -> 1~+2*3
1+2~*3 -> 1+2~*3
1+(2~)*3 -> 1+(2~)*3
1~~ -> 1~~

// Test implicit cons
1 2 -> 1‿2
1 (2*3) -> 1‿(2*3)
(1*2) 3 -> 1*2‿3

1 2 3 -> 1‿2‿3
(1 2) 3 -> 1‿2‿3
1 (2 3) -> 1‿(2‿3)
(1)(2)(3) -> 1‿2‿3
(1)(2) (3) -> 1‿2‿3
(1) (2)(3) -> 1‿2‿3
(1 2) (3 4) -> 1‿2‿(3‿4)
(1 2) 3 (4 5) -> 1‿2‿3‿(4‿5)

// Space can make unary/cons
1~ 2 -> 1~‿2
1 ~ -> 1~
1 2~ -> 1‿2~
1 2 ~ -> 1‿2~
(1~ ) -> 1~

// Test space doesnt do anything else
1 + 2~ -> 1+2~
1 + 2*3 -> 1+2*3
1 +2*3 -> 1+2*3
1+2 * 3+4 -> 1+2*3+4
1+2 3*4 -> 1+2‿3*4
(1+2 ) -> 1+2
( 1+2) -> 1+2

// test unbalanced parens
1+2)+3 -> ParseError
1+(2*3 -> 1+(2*3)

// test trinary operator
1?2)3 -> 1 then 2 else 3
1+(1?2)3) -> 1+(1 then 2 else 3)
1+2?3+4)5+6 -> 1+2 then 3+4 else 5+6
1+2?3+4)(5+6) -> 1+2 then 3+4 else (5+6)
1 then 2 else 3 -> 1 then 2 else 3
1 2?3 4 )5 6 -> 1‿2 then 3‿4 else 5‿6
1 2 then 3 4 else 5 6 -> 1‿2 then 3‿4 else 5‿6
1 ? 2 else 3 -> ParseError
1 ? 2 ) -> 1 then 2 else $
1 ? 2 -> ParseError
1 ? -> ParseError
1 then 2 -> ParseError

// test assignments
a:=1 -> f
1:=a -> ParseError
1:=1 -> ParseError

!3 -> ParseError
// !"" -> ParseError # todo better error
! -> ParseError

"ab"!"cd" -> f
EOF

require "./test/run_lines.rb"

run_tests(tests) { |source|
  tokens = lex(source)
  context={}
  root = parse_line(tokens,context)
  replace_vars(root,context)
  to_infix(root)
}