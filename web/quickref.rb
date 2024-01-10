require "./repl.rb"
require 'cgi'

OpsList.find{|o|!(String === o) && o.name == "readLines"}.sym = "R"
OpsList.find{|o|!(String === o) && o.name == "firstNums"}.sym = "F"

class String
  def td(_class=nil)
    "<td #{'class='+_class.inspect if _class}>"+self.escape+"</td>"
  end
  def escape
    CGI.escape_html self
  end
  def ref
    puts '<tr><td colspan="4" class="center"><b>'+self+'</b></td></tr>'
  end
end

class Op
  def ref
    puts "<tr class=\"code\">"
    puts name.td
    puts (sym||"").td
    if type_summary
      puts type_summary.gsub('->','→').gsub('[Char]','Str').td
    else
      if type.size==1
        type.each{|t|
          puts t.inspect.gsub('->','→').gsub('[Char]','Str').td
        }
      else
        print "<td>"
        puts type[0].inspect.gsub('->','→').gsub('[Char]','Str').escape
        type[1..-1].each{|t|
#           puts "<br>"
          puts t.inspect.gsub('->','→').gsub('[Char]','Str').escape
        }
        puts "</td>"
      end
    end
    print "<td>"
    examples.each_with_index{|example,i|
      print "<span class=\"#{i==0 ? "left" : "right"}\">" + example.gsub('->','→') + "</span>"
    }
    print desc if examples.empty? && desc
    puts "</td>"
#     puts "no_zip=true" if no_zip
    puts "</tr>"
  end
end

puts '<!DOCTYPE HTML >
<html><!-- This file is automatically generated from quickref.rb by reading ops.rb --><head><meta charset="utf-8" /><title>Atlas Quick Ref</title><link rel="stylesheet" href="quickref.css"><link rel="icon" href="favicon.ico"></head><body><table>'

"literals".ref
puts "<tr>","integers".td,"".td,"Num".td("code"),"42 → 42".td("code"),"</tr>"
puts "<tr>","characters".td,"".td,"Char".td("code"),"'d → 'd".td("code"),"</tr>"
puts "<tr>","strings".td,"".td,"Str".td("code"),'"hi" → "hi"'.td("code"),"</tr>"
puts "<tr>","floats".td,"".td,"Num".td("code"),
  '<td class="code">4.50 → 4.5<span class="right">2e3 -> 2000.0</span></td>',"</tr>"
puts "<tr>","empty list".td,"".td,"[a]".td("code"),'() → []'.td("code"),"</tr>"

OpsList.reject{|o| !(String===o) && o.name =~ /^implicit/ }.each{|o|
  o.ref
}
"debug".ref
Commands.each{|str,data|
  desc,arg,impl = data
  puts "<tr>"
  puts str.td("code")
  puts "".td("code")
  puts (arg||"").td("code")
  puts desc.td
  puts "</tr>"
}
"misc".ref
puts "<tr>"
puts "S".td("code")
puts "".td("code"),"Char".td("code"),"space".td
puts "</tr>"
puts "<tr>"
puts "N".td("code")
puts "".td("code"),"Char".td("code"),"newline".td
puts "</tr>"
puts "<tr>"
puts "unset id".td
puts "".td("code"),"Num".td("code")
puts '<td>Roman Numerals<span class="right"><span class="code">MIX → 1009</code></span></td>'
puts "</tr>"
puts "<tr>"
puts "unset id".td
puts "".td("code"),"Char".td("code")
puts 'z → \'z'.td("code")
puts "</tr>"
puts "<tr>"
puts "unset id".td
puts "".td("code"),"Str".td("code")
puts 'Hello → "Hello"'.td("code")
puts "</tr>"
puts "</table>
<br>*a coerces
<br>version: #$version
</body></html>"