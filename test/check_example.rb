require "./repl.rb"
require 'stringio'

def check_example(test)
  i,o=test.split("->")
  o.strip!

  expected = o
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

  if o=~/Error/ ? found.class.to_s!=o : found != expected
    STDERR.puts "FAIL: "+yield
    STDERR.puts i
    STDERR.puts "expected:"
    STDERR.puts expected
    raise found if Exception === found
    STDERR.puts "found:"
    STDERR.puts found
    exit(1)
  end
end

def doit(source,limit)
  tokens,lines = lex(source)
  root = parse_line(tokens[0],[])
  root_ir = to_ir(root,{})
  ir = IR.new(Ops1['show'],[root_ir])
  infer(ir)

  output = StringIO.new
  run(ir, output, limit)
  [output.string,root_ir.type.inspect]
end