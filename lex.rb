# -*- coding: ISO-8859-1 -*-
Token = Struct.new(:str,:char_no,:line_no)

AllSymbols='@!?`~#%^&*-_=+[]|;<,>.()\'"{}$/\\:'.chars.map{|c|Regexp.escape c}

NumRx = /([0-9]+([.][0-9]+)?(e-?[0-9]+)?)|([.][0-9]+(e-?[0-9]+)?)/
CharRx = /'(\\n|\\0|\\x[0-9a-fA-F][0-9a-fA-F]|.)/m
StrRx = /"(\\.|[^"])*"?/
AtomRx = /#{CharRx}|#{NumRx}|#{StrRx}/
SymRx = /#{AllSymbols*'|'}/
CommentRx = /--.*/
IgnoreRx = /#{CommentRx}|[ \t]+/
NewlineRx = /\r\n|\r|\n/
IdRx = /[^#{AllSymbols.join} \t\n\r0-9][^#{AllSymbols.join} \t\n\r]*/ # anything else consecutively, also allow numbers in name if not first char

def lex(code,line_no=1) # returns a list of lines which are a list of tokens
	tokens = [[]]
  char_no = 1
  code.scan(/#{AtomRx}|#{CommentRx}|#{SymRx}|#{NewlineRx}|#{IgnoreRx}|#{IdRx}/m) {|matches|
    token=Token.new($&,char_no,line_no)
    match=$&
    line_no += $&.scan(NewlineRx).size
    if match[NewlineRx]
      char_no = match.size-match.rindex(NewlineRx)
    else
      # FYI this counts tab as 1, and utf8 characters as len of their bytes, could be misleading
      char_no += match.size
    end
    if token.str =~ /^#{IgnoreRx}$/
      # pass
    elsif token.str =~ /^#{NewlineRx}$/
      tokens << []
    else
  	  tokens[-1] << token
  	end
  }
  [tokens,line_no+1]
end

