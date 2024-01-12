# -*- coding: ISO-8859-1 -*-
class Token<Struct.new(:str,:char_no,:line_no)
  def name
    str[/^#{ApplyRx}?(.*?)#{FlipRx}?$/m,1]
  end
  def is_name
    !(OtherRx=~str) && !AllOps[str]
  end
end

AllSymbols='@!?`~#%^&*-_=+[]|;<,>.()\'"{}$/\\:'
UnmodableSymbols='()\'"'.chars.to_a # these cannot have op modifiers
FlipModifier="\\"
FlipRx=Regexp.escape FlipModifier
ApplyModifier="@"
ApplyRx=Regexp.escape ApplyModifier
ModableSymbols=AllSymbols.chars.to_a-UnmodableSymbols-[FlipModifier,ApplyModifier]

NumRx = /([0-9]+([.][0-9]+)?(e-?[0-9]+)?)|([.][0-9]+(e-?[0-9]+)?)/
CharRx = /'(\\n|\\0|\\x[0-9a-fA-F][0-9a-fA-F]|.)/m
StrRx = /"(\\.|[^"])*"?/
AtomRx = /#{CharRx}|#{NumRx}|#{StrRx}/
SymRx = /#{ModableSymbols.map{|c|Regexp.escape c}*'|'}/
OpRx = /#{ApplyRx}?#{SymRx}#{FlipRx}?|#{FlipRx}|#{ApplyRx}{1,2}/
OtherRx = /#{UnmodableSymbols.map{|c|Regexp.escape c}*'|'}/
CommentRx = /--.*/
IgnoreRx = /#{CommentRx}|[ \t]+/
NewlineRx = /\r\n|\r|\n/
AllSymEsc = AllSymbols.chars.map{|c|Regexp.escape c}.join
IdRx = /[^#{AllSymEsc} \t\n\r0-9][^#{AllSymEsc} \t\n\r]*/ # anything else consecutively, also allow numbers in name if not first char

def lex(code,line_no=1) # returns a list of lines which are a list of tokens
	tokens = [[]]
  char_no = 1
  code.scan(/#{AtomRx}|#{CommentRx}|#{OpRx}|#{OtherRx}|#{NewlineRx}|#{IgnoreRx}|#{IdRx}/m) {|matches|
    $from=token=Token.new($&,char_no,line_no)
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
      tokens[-1] << Token.new(:EOL,char_no,line_no)
      tokens << []
    else
  	  tokens[-1] << token
  	end
  }
  tokens[-1]<<Token.new(:EOL,char_no,line_no)
  [tokens,line_no+1]
end

