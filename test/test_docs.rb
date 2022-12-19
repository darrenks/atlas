require 'open3'
runs = 0
$fail = false
def failit(filename,line,prog,expected,output)
  puts "FAIL example: "
  puts prog
  puts "Expecting:", expected
  puts "Found:", output
  puts "from: "+filename+" line: "+line.to_s
  $fail = true
end

(Dir['docs/*.md']<<"README.md").each{|doc|
  file = File.read(doc)
  tests = 0
  file.scan(/((?:    .*\n+)+)    ───+\n((:?    .*\n+)+)/){|a|
    tests += 1
    line=$`.count($/)+1
    prog,expected=*a
    prog.gsub!(/^    /,'')
    expected.gsub!(/^    /,'')

    File.write("test/prog.atl",prog)

    truncate = expected =~ /\.\.\.$/
    expected.gsub!(/\.\.\.$/,'')

    if truncate
      stdout, stderr, status = Open3.capture3("ruby atlas.rb test/prog.atl | head -c #{truncate}")
    else
      stdout, stderr, status = Open3.capture3("ruby atlas.rb test/prog.atl")
    end

    output = stdout + stderr
    output.gsub!(/ *$/,'')
    output.strip!
    expected.strip!

    if output != expected
      failit(doc,line,prog,expected,output)
    else
      runs += 1
    end
  }
  raise "probably have misformatted example" if tests != file.split(/───+/).size-1
}

puts "PASS %d doc tests" % runs if !$fail
