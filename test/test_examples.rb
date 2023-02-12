require 'open3'
runs = 0
def failit(filename,test, reason)
  puts "FAIL example: "
  puts test
  puts reason
  puts "from: "+filename
  exit(1)
end

tests = Dir["test/examples/*.test"]
section_regex = /^\[.*?\]\n/i
tests.each{|test_filename|
  test = File.read(test_filename)
  sections = test.scan(section_regex)
  datum = test.split(section_regex)[1..-1]
  prog = nil
  args = ""
  expected_stderr = input = expected_stdout = ""
  sections.zip(datum){|section,data|
    case section.chomp[1...-1].downcase
    when "input"
      input = data.strip
    when "stdout"
      expected_stdout = data.strip
    when "stderr"
      expected_stderr = (data||"").strip
    when "prog"
      prog = data.strip
    when "args"
      args=data.strip
    else
      raise "unknown section %p" % section
    end
  }
  raise "invalid test #{test_filename}" if expected_stdout=="" && expected_stderr==""

  File.write("test/input", input)
  File.write("test/prog.atl",prog)
  stdout, stderr, status = Open3.capture3("./atlas test/prog.atl < test/input")

  stdout.strip!
  stderr.strip!
  stderr=stderr.split("\e[31m").join
  stderr=stderr.split("\e[0m").join

  if !expected_stderr.empty? && !stderr[expected_stderr] || expected_stderr.empty? && !stderr.empty?
    failit(test_filename,test,"stderr was\n"+stderr)
  elsif stdout != expected_stdout
    failit(test_filename,test,"stdout was\n"+stdout)
  els
  else
    runs += 1
  end
}
puts "PASS %d example runs" % runs
