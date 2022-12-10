require_relative "./lex.rb"
require_relative "./lazylib.rb"
require_relative "./parse.rb"
require_relative "./infer.rb"
require_relative "./to1d.rb"
require_relative "./to_infix.rb"

gets(nil).lines.each{|line|
  if line['#'] || !line['->']
    puts line
    next
  end
  source,ans = line.split('->')

  tokens = lex(source)
  root = parse(tokens)
  #root = parse_infix(tokens)

  # infer(root)
  # STDERR.puts to1d(root)[0]*" "
  # STDERR.puts root.type.inspect
 puts to_infix(root) + ' ->' + ans
}