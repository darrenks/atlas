require_relative "./lex.rb"
require_relative "./lazylib.rb"
require_relative "./parse.rb"
require_relative "./infer.rb"
require_relative "./to_infix.rb"

raise "usage: > ruby atlas.rb filename.atl" if ARGV.size != 1
source = File.read(ARGV[0])

tokens = lex(source)
root = parse_infix(tokens)

infer(root)
STDERR.puts to_infix(root)
STDERR.puts root.type.inspect
make_promises(root)
run(root)

STDERR.puts "\ndynamic reductions: %d" % $reductions
