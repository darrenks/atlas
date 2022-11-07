require_relative "./lex.rb"
require_relative "./lazylib.rb"
require_relative "./parse1d.rb"
require_relative "./infer.rb"
require_relative "./narrow.rb"
require_relative "./to1d.rb"

raise "usage: > ruby atlas.rb filename.{a1d,a2d}" if ARGV.size != 1 || (ext = ARGV[0][/\.a[12]d$/]).empty?
source = File.read(ARGV[0])

if ext == ".a2d"
  tokens = lex2d(source)
  root = narrow(tokens)
  #root.type.value
  #p root.args[0].type.value
  run(root)
else
  tokens = lex1d(source)
  root = parse1d(tokens)

  infer(root)
  STDERR.puts to1d(root)[0]*" "
  STDERR.puts root.args[0].type.inspect
  make_promises(root)
  run(root)

  STDERR.puts "\ndynamic reductions: %d" % $reductions
end