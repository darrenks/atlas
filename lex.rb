class Token<Struct.new(:str,:char_no,:line_no,:space_before,:space_after)
  def name
    str[/!*@?(.*)/m,1]
  end
end


# todo gsub \r\n -> \n and \t -> 8x" " and \r -> \n

NumRegex = /0|[0-9]+/m
CharRegex = /'(\\n|\\0|\\x[0-9a-fA-F][0-9a-fA-F]|.)/m
StrRegex = /"(\\.|[^"])*"?/m
ArgRegex = /(:[0-9]+)|::/m
AtomRegex = /#{CharRegex}|#{NumRegex}|#{StrRegex}|#{ArgRegex}/m
# if change, then change auto complete chars
VarRegex = /[a-z][a-zA-Z0-9_]*|A/m
IdRegex = /!*@?(#{VarRegex}|:=|.)/m
CommentRegex = /\/\/.*/

def assertVar(token)
  raise ParseError.new "cannot set #{token.str}", token unless token.str =~ /^#{VarRegex}$/
end

def lex(code,line_no=1) # returns a list of tokens
  last_was_space = false
	tokens = []
  char_no = 1
  code.scan(/#{AtomRegex}|#{CommentRegex}|#{IdRegex}/m) {|matches|
    $from=token=Token.new($&,char_no,line_no,last_was_space,nil)
    char_no += $&.size
    if token.str =~ /^#{CommentRegex}$/
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

