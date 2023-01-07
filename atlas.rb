require_relative "./lex.rb"
require_relative "./lazylib.rb"
require_relative "./parse.rb"
require_relative "./infer.rb"
require_relative "./to_infix.rb"

raise "usage: > ruby atlas.rb filename.atl" if ARGV.size != 1
source = File.read(ARGV[0])

begin
  tokens = lex(source)
  roots = parse_infix(tokens)

  newline = AST.new(create_str('"\n"'),[])

  root = AST.new(Ops1['_'],[roots.reverse.inject(AST.new(Ops1['$'],[])){|after,line|
    line = AST.new(Ops1['tostring'],[line])
    AST.new(Ops2[':'],[line,AST.new(Ops2[':'],[newline,after])])
  }])

#  root = AST.new(Ops['tostring'],roots)

#
#   puts to_infix(root)

  infer(root)

#   STDERR.puts to_infix(root)
#   STDERR.puts roots[0].type.inspect

  make_promises(root)
  run(root)

  #STDERR.puts "dynamic reductions: %d" % $reductions
rescue AtlasError => e
  STDERR.puts if DynamicError === e
  STDERR.puts e.message
  exit(1)
rescue => e
  STDERR.puts "!!!This is an internal Atlas error, please report the bug (via github issue or email name of this lang at golfscript.com)!!!\n\n"
  raise e
end