require 'open3'
runs = 0
def failit(filename,line,prog,expected,output)
  puts "FAIL doc: "
  puts prog
  puts "Expecting:", expected
  puts "Found:", output
  puts "from: "+filename+" line: "+line.to_s
  exit(1)
end

(Dir['docs/*.md']<<"README.md").each{|doc|
  file = File.read(doc, :encoding => "utf-8")
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

    cmd = "./atlas -doc_mode test/prog.atl"
    if truncate
      stdout, stderr, status = Open3.capture3("#{cmd} | head -c #{truncate}")
    else
      stdout, stderr, status = Open3.capture3(cmd)
    end
    stderr=stderr.split("\e[31m").join
    stderr=stderr.split("\e[0m").join
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

puts "PASS %d doc tests" % runs
