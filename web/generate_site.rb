raise "generate site using utf-8, not %p" % Encoding.default_external if Encoding.default_external != Encoding::UTF_8

allFiles = Dir['docs/*.md']
Basenames = allFiles.map{|f| f.sub(/\.md$/,'').sub('docs/','') } - ["try_it","examples","happenings"]


def convertMd(filename)
  basefile = filename.sub(/\.md$/,'').sub('docs/','')
  basefile = "index" if basefile == "README"
  md = File.read(filename)

  # remove github readme warning
  md = md.lines.to_a[4..-1].join if basefile == "index"

  File.open('t.md','w'){|f|f<<md.gsub(/(\[.*\])\((docs\/)*((.+)\.md)\)/,'\1(\4.html)')}
  markdown = `markdown.pl < t.md`
  `rm t.md`

  is_doc = Basenames.include? basefile

  navbar = '<div class="navbar">
   <a'+(basefile=="index"?' class="active"':'')+' id="atlas" href="index.html">Atlas</a>
   <a '+(is_doc ?' class="active"':'')+' href="circular.html">Docs</a>
   <a href="happenings.html">Happenings</a>
   <a href="examples.html">Examples</a>
   <a href="quickref.html">Quick Ref</a>
   <a href="try_it.html">Try it!</a>
   <a href="https://github.com/darrenks/atlas">Source</a>
   <span style="
   visibility: hidden;
    opacity: 0;
    position: absolute;
    top: -10000px;
    left: -10000px;
    "><!-- create an extra non anchor hidden element due to chrome bug on mobile -->test</span>
</div>
<div '+(is_doc ? '' : 'style="display:none" ')+'class="navbar" id="docs_menu">'+
   Basenames.sort_by(&:downcase).map{|n|
     "<a #{'class="active"' if basefile == n} href=\"#{n}.html\">#{n.split('_').map{|word|word[0].upcase+word[1..-1]}*" "}</a>"
   }*"\n"+'</div>'

  # pre shows up too small on mobile...
  markdown.gsub!("<pre>",'<div class="prog">')
  markdown.gsub!("</pre>",'</div>')

  markdown.gsub!(/────+\n/,'<hr>')

  title = markdown[/<h1>(.*?)<\/h1>/,1]
  title = "Atlas" if filename == "README.md"

  markdown.gsub!(/<(h[1-3])>(.*?)<\/\1>/){"<#$1 id=\"#{$2.downcase.tr'^a-z0-9',''}\">#$2</#$1>"}

  if title.nil?
    puts 'skipping '+filename
    return
  end

  File.open('web/site/'+basefile+'.html','w'){|f|f<<'<!DOCTYPE HTML>
<html lang="en"><!-- This file is automatically generated from generate_site.rb by reading '+filename+' --><head><meta charset="utf-8"><title>'+title+'</title><link rel="stylesheet" href="style.css"><link rel="icon" type="image/x-icon" href="favicon.ico" /></head><body>
'+"\n"+navbar+"<div id=\"content\">"+markdown+"</div>\n"+'</body></html>'}
end

(allFiles<<"README.md").each{|f|
  convertMd(f)
}

`ruby web/package.rb > web/site/atlas && chmod +x web/site/atlas`
raise "problem with atlas package" if `echo 1+2 > test/temp.atl; web/site/atlas test/temp.atl` != "3\n"

