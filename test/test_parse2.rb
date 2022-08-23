# for ambiguous parses that require recursion or type checking to narrow down

require "./ops.rb"
require "./lex.rb"
require "./parse2d.rb"
require "./to1d.rb"
require "./narrow.rb"
require "stringio"

def doit(source)
  tokens = lex(source)
  to1d(narrow(tokens,StringIO.new))[0]*" "
end

line = 1
pass = 0
File.read("./test/parse_tests2.txt").split(/^##.*\n/).map{|test|
  (line+=1; next) if test.strip == ""
  i,o=test.split("\n\n")
  o.strip!
  begin
    found = doit(i)
  rescue
    found = $!
  end

  if o=="error" ? !(Exception === found) : found != o
    STDERR.puts "FAIL: parse test2 line %d" % [line]
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

puts "PASS %d parse tests2" % pass