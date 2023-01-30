require "readline"
Dir["*.rb"].each{|f| require_relative f }

def repl(input=nil,output=STDOUT,step_limit=Float::INFINITY)
  context={}
  line_no = 0

  if !ARGV.empty?
    input_fn = lambda { gets }
  elsif input
    input_fn = lambda { input.gets }
  else
    input_fn = lambda { Readline.readline("\e[33m #{line_no}> \e[0m", true) }
    Readline.completion_append_character = " "
    Readline.completion_proc = lambda{|s|
      all = context.keys + AllOps.values.filter(&:name).map(&:name) + ["then"]
      all -= all.grep(/^see/) if !s[/^see/]
      all.grep(/^#{Regexp.escape(s)}/)
    }
  end

  ast = nil
  file_args = !ARGV.empty?
  assignment = false
  loop {
    prev_context = context.dup
    line_no += 1
    line=input_fn.call
    begin
      # todo set context[line_no] for circular programming, e.g. 1:1
      if line==nil # eof
        printit(ast, context, output, step_limit) if assignment # was last
        break
      end
      tokens = lex(line.chomp, line_no)
      next if tokens[0].str == :EOL

      if tokens.size > 2 && tokens[1].str==":="
        assignment = true
        assertVar(tokens[0])
        ast = context[tokens[0].str] = parse_line(tokens[2..-1],context)
      else
        assignment = false
        ast = parse_line(tokens,context)
        printit(ast, context, output, step_limit)
      end
      context[line_no] = ast
    rescue AtlasError => e
      STDERR.puts e.message
      assignment = false
      context = prev_context
    rescue => e
      STDERR.puts "!!!This is an internal Altas error, please report the bug (via github issue or email name of this lang at golfscript.com)!!!\n\n"
      raise e
    end
  }
end

def printit(ast,context,output,step_limit)
    str_ast = AST.new(Ops1['tostring'],[ast])
    replace_vars(str_ast,context)
#     puts to_infix(str_ast)
    infer(str_ast)
    run(str_ast,output,10000,step_limit)
    output.puts
end