class Token<Struct.new(:str,:char_no,:line_no,:space_before,:space_after)
  def name
    str[/!*@?(.*)/m,1]
  end
end


# todo gsub \r\n -> \n and \t -> 8x" " and \r -> \n

NumRx = /0|[0-9]+/
CharRx = /'(\\n|\\0|\\x[0-9a-fA-F][0-9a-fA-F]|.)/
StrRx = /"(\\.|[^"])*"?/
ArgRx = /(:[0-9]+)|::/
AtomRx = /#{CharRx}|#{NumRx}|#{StrRx}|#{ArgRx}/
# if change, then change auto complete chars
IdRx = /[a-z][a-zA-Z0-9_]*|[A-Z]/
SymRx = /#{' `~@#$%^&*-_=+[]\\|;<,>./?'.chars.map{|c|Regexp.escape c}*'|'}/
OpRx = /(!*@?(#{IdRx}|#{SymRx}))|!+@?|@/
OtherRx = /\:=|[(){}'":]/
CommentRx = /\/\/.*/

def assertVar(token)
  raise ParseError.new "cannot set #{token.str}", token unless token.str =~ /^#{IdRx}$/
end

def lex(code,line_no=1) # returns a list of tokens
  last_was_space = false
	tokens = []
  char_no = 1
  code.scan(/#{AtomRx}|#{CommentRx}|#{OpRx}|#{OtherRx}/m) {|matches|
    $from=token=Token.new($&,char_no,line_no,last_was_space,nil)
    char_no += $&.size
    if token.str =~ /^#{CommentRx}$/
    elsif token.str == " "
      tokens[-1].space_after = token unless tokens.empty?
      last_was_space = true
    else
      last_was_space = false
  	  tokens << token
  	end
  }
  tokens<<Token.new(:EOL,char_no,line_no)
end

