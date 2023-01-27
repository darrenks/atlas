def inspect_char(char)
  return "'\"" if char=='"'.ord # Don't escape this char (we would in a string)
  "'" + escape_str_char(char)
end

def escape_str_char(char)
  raise DynamicError.new "invalid char (negative) %d" % char, nil if char < 0
  return "\\0" if char == "\0".ord
  return "\\n" if char == "\n".ord
  return "\\\\" if char == "\\".ord
  return "\\\"" if char == "\"".ord
  return "%c" % char if char >= " ".ord && char <= "~".ord # all ascii printables
  return "\\x0%s" % char.to_s(16) if char < 16
  return "\\x%s" % char.to_s(16) if char < 256
  return "%c" % char # most unicodes are printable, just print em
end

def parse_char(s)
  ans,offset=parse_str_char(s,0)
  raise "internal char error" if ans.size != 1 || offset != s.size
  ans[0].ord
end

def parse_str_char(s,i) # parse char in a string starting at position i
  if s[i]=="\\"
    if s.size <= i+1
      ["\\",i+1]
    elsif s[i+1] == "n"
      ["\n",i+2]
    elsif s[i+1] == "0"
      ["\0",i+2]
    elsif s[i+1] == "\\"
      ["\\",i+2]
    elsif s[i+1] == "\""
      ["\"",i+2]
    elsif s[i+1,3] =~ /x[0-9a-fA-F][0-9a-fA-F]/
      [s[i+2,2].to_i(16).chr,i+4]
    else
      ["\\",i+1]
    end
  else
    [s[i],i+1]
  end
end

def parse_str(s)
  i=0
  r=""
  while i<s.size
    c,i=parse_str_char(s,i)
    r<<c
  end
  r
end


# test
# 256.times{|ci|
#   s=escape_str_char(ci)
#   c,i=parse_str_char(s,0)
#   p [ci,c.ord,s] if c.ord != ci || s[i..-1]!=""
# }
#
# 256.times{|ci|
#   s=inspect_char(ci)[1..-1]
#   (p ci;next) if s.size > 1
#   c=parse_char(s)
#   p [ci,c.ord,s] if c.ord != ci
# }
