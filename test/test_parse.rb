require "./ops.rb"
require "./lex.rb"
require "./parse2d.rb"
require "./to1d.rb"
require "stringio"

def doit(source)
  tokens = lex(source)
  roots,err = parse2d(tokens,StringIO.new)
  raise "%d parses"%roots.size if roots.size != 1
  to1d(roots[0])[0]*" "
end

line = 1
pass = 0
File.read("./test/parse_tests.txt").split(/^##.*\n/).map{|test|
  (line+=1; next) if test.strip == ""
  i,o=test.split("\n\n")
  o.strip!
  begin
    found = doit(i)
  rescue
    found = $!
  end

  if o=="error" ? !(Exception === found) : found != o
    STDERR.puts "FAIL: parse test line %d" % [line]
    STDERR.puts i
    STDERR.puts "expected:"
    STDERR.puts o
    STDERR.puts "found:"
    STDERR.puts found
    exit(1)
  end

  pass += 1
  line += 3 + i.lines.size
}

puts "PASS %d parse tests" % pass