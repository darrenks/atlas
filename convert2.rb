require_relative "./lex.rb"
require_relative "./lazylib.rb"
require_relative "./parse.rb"
require_relative "./infer.rb"
require_relative "./to1d.rb"
require_relative "./to_infix.rb"

gets(nil).lines.each{|line|
  unless line =~ /^(\s*# (Example|Test): )(.*?) -> (.*)$/
    puts line
    next
  end
  pre,source,ans = [$1,$3,$4]

  tokens = lex(source)
  root = parse(tokens)
  #root = parse_infix(tokens)

  # infer(root)
  # STDERR.puts to1d(root)[0]*" "
  # STDERR.puts root.type.inspect
 puts pre + to_infix(root) + ' -> ' + ans
}