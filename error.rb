#AtlasError = Struct.new(:char_no,:line_no,:message)

def warn(msg, from=nil)
  STDERR.puts to_location(from) + " " + msg
end

def to_location(from)
  token = case from
  when Token
    from
  when AST
    from.token
  when NilClass
    nil
  else
    raise "unknown location type %p " % from
  end

  if token
    "%d:%d (%s)" % [token.line_no, token.char_no, token.str]
  else
    "?:?"
  end
end

class AtlasError < StandardError
  def initialize(message,from)
    @message = message
    @from = from
  end
  def message
    to_location(@from) + " " + @message
  end
end

class DynamicError < AtlasError
end

class InfiniteLoopError < DynamicError
  attr_reader :source
  def initialize(message,source,token)
    @source = source
    super(message,token)
  end
end

class StaticError < AtlasError
end

class AtlasTypeError < StaticError
end

class ParseError < StaticError
end

class LexError < StaticError
  def initialize(message)
    super(message,$from)
  end
end

#raise AtlasTypeError.new("hi",5)