#AtlasError = Struct.new(:char_no,:line_no,:message)

class AtlasError < StandardError
  def initialize(message,token)
    @message = message
    @token = case token
      when Token
        token
      when AST
        token.op.token
      when NilClass

      else
        raise "unknown token type %p " % token
    end
  end
  def message
    if Token===@token
      "\n%d:%d (%s) %s" % [@token.line_no, @token.char_no, @token.str,@message]
    else
      "\n?:? %s" % @message
    end
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