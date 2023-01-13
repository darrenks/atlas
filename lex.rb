class Token<Struct.new(:str,:char_no,:line_no,:space_after)
  def name
    str[/!*(.*)/m,1]
  end
end


# todo gsub \r\n -> \n and \t -> 8x" " and \r -> \n

NumRegex = /0|[0-9]+/m
CharRegex = /'(\\n|\\0|\\x[0-9a-fA-F][0-9a-fA-F]|.)/m
StrRegex = /"(\\.|[^"])*"?/m
AtomRegex = /#{CharRegex}|#{NumRegex}|#{StrRegex}/m
IdRegex = /!*([a-zA-Z][a-zA-Z0-9_]*|==|.)/m
CommentRegex = /\/\/.*/

def lex(code,line_no=1) # returns a list of tokens
	tokens = []
  char_no = 1
  code.scan(/#{AtomRegex}|#{CommentRegex}|#{IdRegex}/m) {|matches|
    $from=token=Token.new($&,char_no,line_no,false)
    char_no += $&.size
    if token.str =~ /^ +$/
      tokens[-1].space_after = true unless tokens.empty?
    elsif token.str =~ /^#{CommentRegex}$/
	  else
  	  tokens << token
  	end
  }
  tokens<<Token.new(:EOF,char_no,line_no)
end

