# Test that parse generates the correct AST
tests = <<'EOF'
1+2 -> 1+2
1+2*3 -> 1+2*3
1+(2*3) -> 1+(2*3)
1~+2*3 -> 1~+2*3
1+2~*3 -> 1+2~*3
1+(2~)*3 -> 1+(2~)*3
1~~ -> 1~~
~2 -> ParseError

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

// Space can prefix a unary op on a single atom
1 ~2 -> 1‿(2~)
1* ~2 -> 1*(2~)
1+2 ~3 -> 1+2‿(3~)
1+2* ~3 -> 1+2*(3~)
1 ~2+3 -> 1‿(2~)+3
1* ~2+3 -> 1*(2~)+3
1 ~~2+3 -> 1‿(2~~)+3
1* ~~2+3 -> 1*(2~~)+3
( ~2) -> 2~

// Test space doesnt do anything else
1 + 2~ -> 1+2~
1 + 2*3 -> 1+2*3
1 ~ -> 1~
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

// !3 -> ParseError todo
// !"" -> ParseError # todo better error
! -> ParseError

//"ab"!"cd" -> todo
EOF

require "./test/run_lines.rb"

run_tests(tests) { |source|
  tokens = lex(source)
  root = parse_line(tokens)
  root.to_infix
}
