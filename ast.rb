class AST < Struct.new(:op,:args,:token,:pre_zip_level,:orig)
  def explicit_zip_level
    token ? token.str[/^!*/].size : 0
  end
  def is_flipped
    token && token.str =~ /^!*@/
  end
end
