Token=Struct.new(:str,:char_no,:line_no,:space_after)

# todo gsub \r\n -> \n and \t -> 8x" " and \r -> \n

NumRegex = /0|[0-9]+/m
CharRegex = /'(\\n|\\0|\\x[0-9a-fA-F][0-9a-fA-F]|.)/m
StrRegex = /"(\\.|[^"])*"?/m
AtomRegex = /#{CharRegex}|#{NumRegex}|#{StrRegex}/m
IdRegex = /!*([a-zA-Z][a-zA-Z0-9_]*|==|.)/m
CommentRegex = /\/\/.*/

def lex(code) # returns a list of tokens
	tokens = []

	scan_with_pos(code,
	    /#{AtomRegex}|#{CommentRegex}|#{IdRegex}/m){|token|
	  if token.str =~ /^ +$/
	    tokens[-1].space_after = true unless tokens.empty?
	  elsif token.str =~ /^#{CommentRegex}$/
	  else
  	  tokens << token
  	end
	}
	tokens
end

def scan_with_pos(str,regex)
  char_no = line_no = 1
  str.scan(regex) {|matches|
    yield($from=Token.new($&,char_no,line_no,false))
    if $&.include?($/)
			char_no = $&.size - $&.rindex($/)
			line_no += $&.count($/)
		else
			char_no += $&.size
		end
  }
end
