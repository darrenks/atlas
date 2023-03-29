require "./repl.rb"

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
  ir = to_ir(root,{})
  infer(ir)
  v=make_promises(ir)
  v=inspect_value(ir.type+ir.vec_level,v,ir.vec_level)
  v=take(limit,v.const)

  [to_eager_str(v.const),ir.type.inspect]
end