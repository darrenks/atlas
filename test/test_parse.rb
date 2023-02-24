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

// Identifiers ->
AA -> A‿A
aA -> aA
a_a -> a_a
A_ A -> A_‿A

1; head 2 -> 1;[‿2

EOF

require "./test/run_lines.rb"

run_tests(tests) { |source|
  tokens,lines = lex(source)
  root = parse_line(tokens[0])
  root.to_infix
}
