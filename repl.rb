require "readline"

def repl
  context={}
  line_no = 0
  assignment = false
  ast = nil
  file_args = !ARGV.empty?
  loop {
    line=file_args ? gets : Readline.readline("> ", true)
    line_no += 1
    begin
      if line==nil
        printit(ast, context) if assignment # was last
        exit
      end
      tokens = lex(line.chomp, line_no)
      next if tokens[0].str == :EOF
      assignment = tokens.size > 2 && tokens[-3].str=="="
      ast = parse_line(tokens,context)
      next if assignment
      printit(ast, context)
    rescue AtlasError => e
      STDERR.puts e.message
      assignment = false
    rescue => e
      STDERR.puts "!!!This is an internal Altas error, please report the bug (via github issue or email name of this lang at golfscript.com)!!!\n\n"
      raise e
    end
  }
end

def printit(ast,context)
    str_ast = AST.new(Ops1['tostring'],[ast])
    replace_vars(str_ast,context)
    infer(str_ast)
    make_promises(str_ast)
    run(str_ast)
    puts
end