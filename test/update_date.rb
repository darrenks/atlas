s=File.read('Ops.rb')
s.gsub!(/Atlas Alpha \(.*?\)/) { "Atlas Alpha (#{Time.now.strftime("%b %d, %Y")})"}
File.open('Ops.rb','w'){|f|f<<s}