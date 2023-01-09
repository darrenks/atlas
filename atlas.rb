require_relative "./lex.rb"
require_relative "./lazylib.rb"
require_relative "./parse.rb"
require_relative "./infer.rb"
require_relative "./to_infix.rb"

options,filenames = ARGV.partition{|arg|arg[0,2]=="--"}
debug = options.delete("--debug")

raise "Usage: ruby atlas.rb [--debug] filename.atl" if filenames.size != 1 || !options.empty?

source = File.read(filenames[0])

begin
  tokens = lex(source)
  roots = parse_infix(tokens)

  newline = AST.new(create_str('"\n"'),[])

  root = AST.new(Ops1['_'],[roots.reverse.inject(AST.new(Ops1['$'],[])){|after,line|
    line = AST.new(Ops1['tostring'],[line])
    AST.new(Ops2[':'],[line,AST.new(Ops2[':'],[newline,after])])
  }])

  infer(root)

  if debug
    STDERR.puts "ANNOTATED PROGRAM:"
    roots.each{|r|
      STDERR.puts to_infix(r) + " // " + r.type.inspect
    }
#     exit
    STDERR.puts "OUTPUT:"
  end

  make_promises(root)
  run(root)

  STDERR.puts "REDUCTIONS: %d" % $reductions if debug
rescue AtlasError => e
  STDERR.puts if DynamicError === e
  STDERR.puts e.message
  exit(1)
rescue => e
  STDERR.puts "!!!This is an internal Atlas error, please report the bug (via github issue or email name of this lang at golfscript.com)!!!\n\n"
  raise e
end