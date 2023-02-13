s=File.read('Ops.rb')
s.sub!(/Atlas Alpha \(.*?\)/) { "Atlas Alpha (#{Time.now.strftime("%b %d, %Y")})"}
File.open('Ops.rb','w'){|f|f<<s}