require "readline"
Dir[__dir__+"/*.rb"].each{|f| require_relative f }
HistFile = Dir.home + "/.atlas_history"

def repl(input=nil,step_limit=nil,output_limit=nil,golf_mode=nil)
  context={}
  context["lastAns"]=to_ir(AST.new(Ops0['input'],[],Token.new("bof")),context)
  last=AST.new(Var,[],Token.new("lastAns"))

  stack=3.downto(0).map{|i|
    AST.new(create_op(
      name: "col#{i}",
      type: VecOf.new(Int),
      impl: int_col(i)
    ),[])
  }

  line_no = 1

  if input
    golf_mode = false if golf_mode.nil?
    step_limit = 1000000 if step_limit == nil
    output_limit = 10000 if output_limit == nil
    input_fn = lambda { input.gets(nil) }
  elsif !ARGV.empty?
    golf_mode = true if golf_mode.nil?
    step_limit = 0 if step_limit == nil
    output_limit = 0 if output_limit == nil
    input_fn = lambda { gets(nil) }
  else
    golf_mode = false if golf_mode.nil?
    step_limit = 1000000 if step_limit == nil
    output_limit = 10000 if output_limit == nil
    if File.exist? HistFile
      Readline::HISTORY.push *File.read(HistFile).split("\n")
    end
    input_fn = lambda {
      line = Readline.readline("\e[33m ᐳ \e[0m", true)
      File.open(HistFile,'a'){|f|f.puts line} unless !line || line.empty?
      line
    }
    Readline.completion_append_character = " "
    Readline.basic_word_break_characters = " \n\t1234567890~`!@\#$%^&*()_-+={[]}\\|:;'\",<.>/?"
    Readline.completion_proc = lambda{|s|
      all = context.keys + ActualOpsList.filter(&:name).map(&:name) + Commands.keys
      all.grep(/^#{Regexp.escape(s)}/)
    }
  end

  { "stepLimit" => step_limit,
  "outputLimit" => output_limit,
  "reductions" => 0,
  "golfMode" => golf_mode ? 1 : 0 }.each{|name,val|
    context[name]=to_ir(AST.new(create_int(val),[],Token.new("bof")),context)
  }


  ast = nil
  file_args = !ARGV.empty?
  assignment = false
  stop = false
  until stop
    prev_context = context.dup
    line=input_fn.call
    begin
      if line==nil # eof
        stop = true # incase error is caught we still wish to stop
        if assignment # was last
          ir = to_ir(ast,context)
          printit(ir, context)
        end
        break
      end
      token_lines,line_no=lex(line, line_no)
      token_lines.each{|tokens| # each line
        next if tokens[0].str == :EOL

        assignment = false
        if (command=Commands[tokens[0].str])
          tokens.shift
          command[2][tokens, stack, last, context]
        elsif !command && (command=Commands[tokens[-2].str])
          tokens.delete_at(-2)
          command[2][tokens, stack, last, context]
        elsif tokens.size > 3 && tokens[1].str=="=" && tokens[0].is_name && !is_op(tokens[2])
          assignment = true
          ast = parse_line(tokens[2..-1], stack, last)
          set(tokens[0], ast, context)
        else
          ir = to_ir(parse_line(tokens, stack, last),context)
          context["lastAns"]=ir
          printit(ir, context)
        end
      }
    rescue AtlasError => e
      STDERR.puts e.message
      assignment = false
      context = prev_context
    rescue SystemStackError => e
      STDERR.puts DynamicError.new("stack overflow error", nil).message
      assignment = false
      context = prev_context
    rescue => e
      STDERR.puts "!!!This is an internal Altas error, please report the bug (via github issue or email name of this lang at golfscript.com)!!!\n\n"
      raise e
    end
  end # until
end

def printit(ir, context)
    infer(ir)
    run(ir, context) {|v| to_string(ir.type+ir.vec_level,v,context["golfMode"].get_value != 0) }
    puts unless $last_was_newline
end