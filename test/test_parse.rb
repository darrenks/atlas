# Test that parse generates the correct AST
tests = <<'EOF'
1+2 -> 1+2
1+2*3 -> 1+2*3
1+(2*3) -> 1+(2*3)
1~+2*3 -> 1~+2*3
1+2~*3 -> 1+2~*3
1+(2~)*3 -> 1+(2~)*3
1~~ -> 1~~

-- Test implicit
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

-- Test space doesnt do anything
1 + 2~ -> 1+2~
1 + 2*3 -> 1+2*3
1 ~ -> 1~
1+2 * 3+4 -> 1+2*3+4
1+2 3*4 -> 1+2 3*4
(1+2 ) -> 1+2
( 1+2) -> 1+2

-- test unbalanced parens
1+2)+3 -> 1+2+3
1+(2*3 -> 1+(2*3)

-- Identifiers
AA -> AA
aA -> aA
a_a -> a_a
A_ A -> A_ A

-- Test binary character identifiers
->   -- chr two char 127 in a row
λλ -> λλ -- two unicode chars in a row

1; head -> 1;[

-- Test apply
1+2@+3 -> 1+(2+3)
1+2@+3@+4 -> 1+(2+(3+4))
1-2~@+3 -> 1-(2~+3)
1+2~\@+3 -> 1+(2~\+3)
1+2@~+3 -> 1+(2~)+3
1+2@~@+3 -> 1+(2~+3)
-- 1+2@+3- -> 1+(2+3)-
1+2@+3-4 -> 1+(2+3)-4
1@+2 -> 1+2
1@~ -> 1~
1+(1+5-)@- -> 1+((1+5-)-)

-- 1+2@3 -> 1+(2 3)
--1@ -> ParseError
1@1 -> 1@1
-- 1@a -> 1@a
EOF

require "./repl.rb"

class AST
  def ==(rhs)
    # ignore paren vars
    return args[0]==rhs if self.op.name == "set" && args[1].token.str[/_/]
    return rhs.args[0]==self if rhs.op.name == "set" && rhs.args[1].token.str[/_/]
    self.op == rhs.op && self.args.zip(rhs.args).all?{|s,r|s==r}
  end
  def inspect
    return self.token.str if self.op.name == "data"
    self.op.name + " " + self.args.map(&:inspect)*" "
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
  next if test.strip == "" || test =~ /^--/
  i,o=test.split("-"+">")
  STDERR.puts "INVALID test #{test}" if !o
  o.strip!
  begin
    tokens,lines = lex(i)
    found = parse_line(tokens[0])

    tokens,lines = lex(o)
    expected = parse_line(tokens[0])
  rescue Exception
    found = $!
  end

  if o=~/Error/ ? found.class.to_s!=o : found != expected
    STDERR.puts "FAIL: #{name} test line #{start_line}"
    STDERR.puts i
    STDERR.puts "expected:"
    STDERR.puts expected.inspect
    STDERR.puts "found:"
    raise found if Exception === found
    STDERR.puts found.inspect
    exit(1)
  end

  pass += 1
}

puts "PASS #{pass} #{name} tests"
