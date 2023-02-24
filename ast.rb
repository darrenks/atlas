class AST < Struct.new(:op,:args,:token,:orig)
  def is_flipped
    token && token.str =~ /^!*@/
  end
end
