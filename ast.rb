class AST < Struct.new(:op,:args,:token)
  def explicit_zip_level
    token ? token.str[/^!*/].size : 0
  end
  def is_flipped
    token && token.str =~ /^!*@/
  end
end
