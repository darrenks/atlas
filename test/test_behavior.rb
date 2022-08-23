require "./ops.rb"
require "./lex.rb"
require "./parse1d.rb"
require "./type.rb"
require "./infer.rb"
require "./lazylib.rb"
require "./type_check.rb"

require 'stringio'

def doit(source,limit)
  tokens = lex1d(source)
  root = parse1d(tokens)
  infer(root)
  type_check(root)

  type = root.args[0].args[0].type.value
  output = StringIO.new
  run(root, limit, output)
  [output.string,type.inspect]
end

line = 1
pass = 0
File.read("./test/behavior_tests.txt").lines.map{|test|
  (line+=1; next) if test.strip == "" || test =~ /^\#/
  i,o=test.split("->")
  o.strip!

  expected,expected_type = if o =~ / : /
    [$`,$']
  else
    [o,nil]
  end
  expected,limit = if expected =~ /\.\.\.$/
    [$`,$`.size]
  else
    [expected,10000]
  end

  begin
    found,found_type = doit("`" + i, limit)
  rescue Exception
   found = $!
  end

  if o=~/Error/ ? found.class.to_s!=o : found != expected || (expected_type != nil && expected_type != found_type)
    STDERR.puts "FAIL: behavior test line %d" % [line]
    STDERR.puts i
    if expected != found
      STDERR.puts "expected:"
      STDERR.puts expected
      STDERR.puts "found:"
      STDERR.puts found
    else
      STDERR.puts "expected type:"
      STDERR.puts expected_type
      STDERR.puts "found_type:"
      STDERR.puts found_type
    end
    exit(1)
  end

  pass += 1
  line += 1
}

puts "PASS %d behavior tests" % pass