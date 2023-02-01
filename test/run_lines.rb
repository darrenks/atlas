require "./repl.rb"

def run_tests(tests,start_line=2)
  pass = 0
  name = $0.sub('test/test_','').sub(".rb","")
  tests.lines.each{|test|
    start_line += 1
    next if test.strip == "" || test =~ /^\/\//
    i,o=test.split("-"+">")
    STDERR.puts "INVALID test #{test}" if !o
    o.strip!
    expected = o

    begin
      found = yield(i)
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
end
