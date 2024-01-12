def warn(msg, from=nil)
  STDERR.puts to_location(from) + msg + " (\e[31mWarning\e[0m)"
end

def to_location(from)
  token = case from
  when Token
    from
  when AST
    from.token
  when IR
    from.from.token
  when NilClass
    nil
  else
    raise "unknown location type %p " % from
  end

  if token
    "%s:%s (%s) " % [token.line_no||"?", token.char_no||"?", token.str]
  else
    ""
  end
end

class AtlasError < StandardError
  def initialize(message,from)
    @message = message
    @from = from
  end
  def message
    to_location(@from) + @message + " (\e[31m#{class_name}\e[0m)"
  end
  def class_name
    self.class.to_s
  end
end

class DynamicError < AtlasError
end

class InfiniteLoopError < AtlasError
  attr_reader :source
  def initialize(message,source,token)
    @source = source # no longer needed, cleanup
    super(message,token)
  end
end

class StaticError < AtlasError
end

# Named this way to avoid conflicting with Ruby's TypeError
class AtlasTypeError < StaticError
  def class_name
    "TypeError"
  end
end

class ParseError < StaticError
end

class LexError < StaticError
  def initialize(message)
    super(message,$from)
  end
end
