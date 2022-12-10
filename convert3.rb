require_relative "./lex.rb"
require_relative "./lazylib.rb"
require_relative "./parse.rb"
require_relative "./infer.rb"
require_relative "./to1d.rb"
require_relative "./to_infix.rb"

gets(nil).lines.each{|line|
  if line[/^#/] || !(line =~ /^(.*?) -> (.*)$/)
    puts line
    next
  end
  source,ans = [$1,$2]

  tokens = lex(source)
  root = parse(tokens)
  #root = parse_infix(tokens)

  before = to_infix(root)
  if !ans['Error']
    infer(root)
    ans = to_infix(root)
  end
  # STDERR.puts to1d(root)[0]*" "
  # STDERR.puts root.type.inspect
 puts before + ' -> ' + ans
}