require "readline"
Dir[__dir__+"/*.rb"].each{|f| require_relative f }

def repl(input=nil)
  context={}
  context["last ans"]=to_ir(AST.new(Ops0['input'],[],Token.new("bof")),context)
  last=AST.new(Var,[],Token.new("last ans"))

  stack=3.downto(0).map{|i|
    AST.new(create_op(
      name: "col#{i}",
      type: VecOf.new(Num),
      impl: num_col(i)
    ),[])
  }

  line_no = 1

  { "N" => "'\n",
    "S" => "' ",
  }.each{|name,val|
    context[name]=to_ir(AST.new(create_char(val),[],Token.new("bof")),context)
  }

  if input
    input_fn = lambda { input.gets(nil) }
  elsif !ARGV.empty?
    input_fn = lambda { ARGV.empty? ? nil : File.read(ARGV.shift, :encoding => 'iso-8859-1') }
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
      all = context.keys + ActualOpsList.filter(&:name).map(&:name) + Commands.keys
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
          ir = to_ir(parse_line(assignment, stack, last),context)
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
          command[2][tokens, stack, last, context]
        elsif !command && (command=Commands[tokens[-2].str])
          tokens.delete_at(-2)
          command[2][tokens, stack, last, context]
        elsif tokens.size > 3 && tokens[1].str=="=" && tokens[0].is_name && !is_op(tokens[2])
          assignment = [tokens[0],tokens[-1]] # code to then get value of this var
          ast = parse_line(tokens[2..-1], stack, last)
          set(tokens[0], ast, context)
        else
          ir = to_ir(parse_line(tokens, stack, last),context)
          context["last ans"]=ir
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

def printit(ir,context)
  n=context['N'].get_str_value || [10.const,Null]
  s=context['S'].get_str_value || [32.const,Null]

  infer(ir)
  puts "\e[38;5;243m#{ir.type_with_vec_level.inspect}\e[0m" if $repl_mode
  run(ir,n,s) {|v,n,s| to_string(ir.type+ir.vec_level,v,$repl_mode||$doc_mode,n,s) }
end