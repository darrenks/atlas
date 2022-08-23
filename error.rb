#AtlasError = Struct.new(:char_no,:line_no,:message)

class AtlasError < StandardError
  def initialize(message,token)
    @token,@message = token,message
  end
  def message
    if Token===@token
      "\n%d:%d (%s) %s" % [@token.line_no, @token.char_no, @token.str,@message]
    else
      "\n?:? %s" % @message
    end
  end
end

class InfiniteLoopError < AtlasError
end

class DynamicError < AtlasError
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