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

// Test implicit
1 2 -> 1 2
1 (2*3) -> 1 (2*3)
(1*2) 3 -> 1*2 3

1 2 3 -> 1 2 3
(1 2) 3 -> 1 2 3
1 (2 3) -> 1 (2 3)
(1)(2)(3) -> 1 2 3
(1)(2) (3) -> 1 2 3
(1) (2)(3) -> 1 2 3
(1 2) (3 4) -> 1 2 (3 4)
(1 2) 3 (4 5) -> 1 2 3 (4 5)

// Test space doesnt do anything
1 + 2~ -> 1+2~
1 + 2*3 -> 1+2*3
1 ~ -> 1~
1+2 * 3+4 -> 1+2*3+4
1+2 3*4 -> 1+2 3*4
(1+2 ) -> 1+2
( 1+2) -> 1+2

// test unbalanced parens
1+2)+3 -> 1+2+3
1+(2*3 -> 1+(2*3)

// Identifiers
AA -> A A
aA -> aA
a_a -> a_a
A_ A -> A_ A

1; head -> 1;[

// Test apply
1+2@+3 -> 1+(2+3)
1+2@+3@+4 -> 1+(2+(3+4))
1+2~@+3 -> 1+(2~+3)
1+2~\@+3 -> 1+(2~\+3)
1+2@~+3 -> 1+(2~)+3
1+2@~@+3 -> 1+(2~+3)
1@+2 -> 1+2
1@~ -> 1~
1@ -> ParseError
1@1 -> 1@1
1@a -> 1@a
EOF

require "./repl.rb"

class AST
  def ==(rhs)
    self.op == rhs.op && self.args.zip(rhs.args).all?{|s,r|s==r}
  end
end

class Op
  def ==(rhs)
    self.name == rhs.name
  end
end

start_line=2
pass = 0
name = $0.sub('test/test_','').sub(".rb","")
tests.lines.each{|test|
  start_line += 1
  next if test.strip == "" || test =~ /^\/\//
  i,o=test.split("-"+">")
  STDERR.puts "INVALID test #{test}" if !o
  o.strip!
  begin
    tokens,lines = lex(i)
    found = parse_line(tokens[0],[])

    tokens,lines = lex(o)
    expected = parse_line(tokens[0],[])
  rescue Exception
    found = $!
  end

  if o=~/Error/ ? found.class.to_s!=o : found != expected
    STDERR.puts "FAIL: #{name} test line #{start_line}"
    STDERR.puts i
    STDERR.puts "expected:"
    STDERR.puts expected
    STDERR.puts "found:"
    raise found if Exception === found
    STDERR.puts found
    exit(1)
  end

  pass += 1
}

puts "PASS #{pass} #{name} tests"
