require "./ops.rb"
require "./lex.rb"
require "./parse.rb"
require "./type.rb"
require "./infer.rb"
require "./lazylib.rb"

require 'stringio'

def doit(source,limit)
  tokens = lex(source)
  roots = parse_infix(tokens)
  raise "must be 1 expr but found %d in %s" % [roots.size,source] if roots.size != 1
  root = roots[0]
  inspect_root = AST.new(Ops['`'],roots)
  infer(inspect_root)

  output = StringIO.new
  run(inspect_root, limit, output)
  [output.string,root.type.inspect]
end

line = 1
pass = 0
behavior_tests = File.read("./test/behavior_tests.txt").lines.to_a
example_regex = /^ *# ?(Example|Test): */
example_tests = File.read("ops.rb").lines.grep(example_regex).map{|line|line.gsub(example_regex,"")}
(behavior_tests + example_tests).map{|test|
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
    found,found_type = doit(i, limit)
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
