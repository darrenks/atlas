require_relative "./lex.rb"
require_relative "./lazylib.rb"
require_relative "./parse.rb"
require_relative "./infer.rb"
require_relative "./to_infix.rb"

raise "usage: > ruby atlas.rb filename.atl" if ARGV.size != 1
source = File.read(ARGV[0])

tokens = lex(source)
roots = parse_infix(tokens)

newline = AST.new(create_str('"\n"'),[])

root = AST.new(Ops['_'],[roots.reverse.inject(AST.new(Ops['$'],[])){|after,line|
  line = AST.new(Ops['tostring'],[line])
  AST.new(Ops[':'],[line,AST.new(Ops[':'],[newline,after])])
}])

#puts to_infix(root)

infer(root)
#STDERR.puts to_infix(root)
#STDERR.puts root.type.inspect
make_promises(root)
run(root)

#STDERR.puts "dynamic reductions: %d" % $reductions
