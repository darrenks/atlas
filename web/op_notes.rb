require './repl.rb'
require 'stringio'

File.open("docs/op_notes.md","w"){|f|
  f<<'
# Op Notes

This page is auto generated and shows the `help <op>` for any op that was deemed complicated enough to require a description.

---
'

  ActualOpsList.each{|op|
    next if !op.desc
    s=StringIO.new
    op.help(s)
    f<<s.string.gsub(/^/,'    ')
  }
}
