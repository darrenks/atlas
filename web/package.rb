files = Dir['*.rb'] - ["type.rb", "spec.rb","version.rb"]
files[files.index("ops.rb"),0] = ["type.rb", "spec.rb"]
files.unshift "version.rb"
files << "atlas"
source = ""
files.each{|file|
  source << File.read(file) << "\n"
}
source['Dir[__dir__+"/*.rb"].each{|f| require_relative f }'] = ''
source.gsub!(/require_relative.*/,'')
source.gsub!(/^\s*/,'')
source.gsub!(/^#.*/,'')
source = "#!/usr/bin/env ruby\n# -*- coding: ISO-8859-1 -*-\n" + source
source.gsub!(/\n\n+/,"\n")
puts source
