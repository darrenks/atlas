require_relative "./lex.rb"
require_relative "./narrow.rb"
require_relative "./lazylib.rb"
require_relative "./parse1d.rb"
require_relative "./infer.rb"
require_relative "./type_check.rb"

raise "usage: > ruby atlas.rb filename.{a1d,a2d}" if ARGV.size != 1 || (ext = ARGV[0][/\.a[12]d$/]).empty?
source = File.read(ARGV[0])

if ext == ".a2d"
  tokens = lex(source)
  root = narrow(tokens)
  #root.type.value
  #p root.args[0].type.value
  run(root)
else
  tokens = lex1d(source)
  root = parse1d(tokens)
  infer(root)
  type_check(root)

  STDERR.puts root.args[0].type.value.inspect
  STDERR.puts "static reductions: %d" % $reductions
  $reductions = 0
  #root.type.value

  run(root)

  STDERR.puts "\ndynamic reductions: %d" % $reductions
end