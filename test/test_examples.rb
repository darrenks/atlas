# This was written to test 2d examples, TODO conver them to 1d

runs = 0
fail = false
dirs = Dir["./test/examples/*"]
dirs.each{|dir|
  ins = Dir["#{dir}/in*.txt"]
  if ins.empty?
    ins = ["/dev/null"]
    outs = ["#{dir}/out.txt"]
  else
    outs = ins.map{|i|i.sub(/in(\d+).txt/,'out\1.txt')}
  end
  ins.zip(outs) {|i,o|
    out = `ruby atlas.rb #{dir}/prog.a2d < #{i} 2> /dev/null | diff #{o} -`
    unless out.strip.empty?
      fail = true
      puts "FAIL example: %s < %s" % [dir, i]
    end
    runs += 1
  }
}
puts "PASS %d example runs" % runs if !fail