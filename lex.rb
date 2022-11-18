require_relative "./ops.rb"

Token=Struct.new(:str,:char_no,:line_no)

# todo gsub \r\n -> \n and \t -> 8x" " and \r -> \n

NumRegex = /0|[0-9]+/m
CharRegex = /'(\\n|\\0|\\x[0-9a-fA-F][0-9a-fA-F]|.)/m
StrRegex = /"(\\.|[^"])*"?/m
AtomRegex = /#{CharRegex}|#{NumRegex}|#{StrRegex}/m
IdRegex = /!*([a-zA-Z][a-zA-Z0-9_]*|.)/m
CommentRegex = /\#[^\n]*/m

def lex(code) # returns a list of tokens
	tokens = []

	ops = Ops.dup
	Ops.each{|key,op| ops[op.name] = op }

	scan_with_pos(code,
	    /#{AtomRegex}|#{CommentRegex}|#{IdRegex}/m){|token|
	  next if token.str =~ /^\#.*|^ +$/
	  # kinda hacky to do this here, but inc these since 2d pads
	  token.char_no += 1; token.line_no += 1
	  op = get_op(token,ops) { Op.new(
	    name: "var",
	    type: {A => A})
	  }
	  tokens << op
	}
	tokens
end

def scan_with_pos(str,regex)
  char_no = line_no = 0
  str.scan(regex) {|matches|
    yield($from=Token.new($&,char_no,line_no))
    if $&.include?($/)
			char_no = $&.size - $&.rindex($/) - 1
			line_no += $&.count($/)
		else
			char_no += $&.size
		end
  }
end

def get_op(token,ops) # takens block for what to do for identifiers
  str = token.str
  op = if str[0] =~ /[0-9]/
    create_int(str)
  elsif str[0] == '"'
    create_str(str)
  elsif str[0] == "'"
    create_char(str)
#   elsif is_special_zip(str)
#     ops[str].dup
  elsif ops.include? str[/!*(.*)/m,1]
    ops[str[/!*(.*)/m,1]].dup
  elsif str != $/
    yield
  else
    Newline
  end
  op.token = token
  op
end

Newline = Op.new(name: "newline")