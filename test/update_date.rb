s=File.read('version.rb')
s.gsub!(/Atlas \S+ \(.*?\)/) { "Atlas Beta (#{Time.now.strftime("%b %d, %Y")})"}
File.open('version.rb','w'){|f|f<<s}