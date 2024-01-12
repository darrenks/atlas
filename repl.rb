require "readline"
Dir[__dir__+"/*.rb"].each{|f| require_relative f }

def repl(input=nil)
  context={}
  saves = []

  bof = Token.new("bof")
  context["last_ans"]=to_ir(AST.new(Ops0['readLines'],[],bof),context,saves)
  last=AST.new(Var,[],Token.new("last_ans"))

  line_no = 1

  { "N" => "'\n",
    "S" => "' ",
  }.each{|name,val|
    context[name]=to_ir(AST.new(create_char(val),[],bof),context,saves)
  }
  context["R"]=to_ir(AST.new(Ops0['readLines'],[],bof),context,saves)
  context["F"]=to_ir(AST.new(Ops0['firstNums'],[],bof),context,saves)

  if input
    input_fn = lambda { input.gets(nil) }
  elsif !ARGV.empty?
    input_fn = lambda { ARGV.empty? ? nil : File.read(ARGV.shift,
      # treat file as byte characters
      :encoding => 'iso-8859-1'
    ) }
  else
    $repl_mode = true if $repl_mode.nil?
    hist_file = Dir.home + "/.atlas_history"
    if File.exist? hist_file
      Readline::HISTORY.push *File.read(hist_file).split("\n")
    end
    input_fn = lambda {
      line = Readline.readline("\e[33m ᐳ \e[0m", true)
      File.open(hist_file,'a'){|f|f.puts line} unless !line || line.empty?
      line
    }
    Readline.completion_append_character = " "
    Readline.basic_word_break_characters = " \n\t1234567890~`!@\#$%^&*()_-+={[]}\\|:;'\",<.>/?"
    Readline.completion_proc = lambda{|s|
      var_names = context.keys.grep(/^[^_]*$/) # hide internal vars
      all = var_names + ActualOpsList.filter(&:name).map(&:name) + Commands.keys
      all.grep(/^#{Regexp.escape(s)}/).reject{|name|name =~ / /}
    }
  end

  file_args = !ARGV.empty?
  assignment = false
  stop = false
  until stop
    prev_context = context.dup
    begin
      line=nil
      line=input_fn.call
      if line==nil # eof
        stop = true # incase error is caught we still wish to stop
        if assignment # was last
          ir = to_ir(parse_line(assignment, last),context,saves)
          printit(ir,context)
        end
        break
      end
      token_lines,line_no=lex(line, line_no)
      token_lines.each{|tokens| # each line
        next if tokens[0].str == :EOL

        assignment = false
        if (command=Commands[tokens[0].str])
          tokens.shift
          command[2][tokens, last, context, saves]
        elsif !command && (command=Commands[tokens[-2].str])
          tokens.delete_at(-2)
          command[2][tokens, last, context, saves]
        elsif tokens[0].str=="let" || possible_assignment(tokens) && !context[tokens[0].str]
          if tokens[0].str == "let"
            raise ParseError.new("let syntax is: let var = value", tokens[0]) unless tokens.size > 4 && tokens[2].str=="=" && tokens[1].is_name
            offset = 1
          else
            offset = 0
          end
          name = tokens[offset]
          assignment = [name,tokens[-1]] # code to then get value of this var
          ast = parse_line(tokens[offset+2..-1], last)
          set(name, ast, context, saves)
        else
          if $repl_mode && possible_assignment(tokens)
            warn("interpreting as equality check, to override name use let var=value", tokens[1])
          end
          ir = to_ir(parse_line(tokens, last),context,saves)
          context["last_ans"]=ir
          printit(ir,context)
        end
      }
    rescue AtlasError => e
      STDERR.puts e.message
      assignment = false
      context = prev_context
    # TODO there are some errors that could come from floats like
    # 0.0^(1.0-)+'a RangeError
    # converting inf to int FloatDomainError
    # "asdf"[(1-^(0.5)) NoMethodError (< on complex)
    # it would be best to catch them higher up for use with truthy
    rescue SignalException => e
      exit if !ARGV.empty? || input # not repl mode
      STDERR.print "CTRL-D to exit" if !line
      puts
    rescue SystemStackError => e
      STDERR.puts DynamicError.new("stack overflow error", nil).message
      assignment = false
      context = prev_context
    rescue Errno::EPIPE
      exit
    rescue => e
      STDERR.puts "!!!This is an internal Altas error, please report the bug (via github issue or email name of this lang at golfscript.com)!!!\n\n"
      raise e
    end
  end # until
end

def possible_assignment(tokens)
  (tokens.size > 3 && tokens[1].str=="=" && tokens[0].is_name && !is_op(tokens[2]))
end

def printit(ir,context)
  infer(ir)
  puts "\e[38;5;243m#{ir.type_with_vec_level.inspect}\e[0m" if $repl_mode
  run(ir) {|v| to_string(ir.type+ir.vec_level,v,$repl_mode||$doc_mode) }
end