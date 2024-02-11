# -*- coding: ISO-8859-1 -*-
# Set ruby file coding (with top comment) and IO to operate on bytes.
# This is done so that everything is simply bytes in Atlas, but will display
# properly even if using fancy unicode chars in another encoding (lengths/etc will be off though).
# It is important for all encodings to match otherwise will get runtime errors when using
# fancy characters.
Encoding.default_external="iso-8859-1"
Encoding.default_internal="iso-8859-1"

Dir[__dir__+"/*.rb"].each{|f| require_relative f }

def repl(input=nil)
  context={}

  { "N" => "'\n",
    "S" => "' ",
  }.each{|name,val|
    context[name]=to_ir(AST.new(create_char(Token.new(val)),[]),{},nil)
  }

  IO_Vars.each{|k,v| context[k] = to_ir(AST.new(Ops0[v],[]),{},nil) }

  # hold off on these, should it be vec or list?
#   context["W"]=to_ir(AST.new(Ops0['wholeNumbers'],[]),{},nil)
#   context["Z"]=to_ir(AST.new(Ops0['positiveIntegers'],[]),{},nil)

  line_no = 1
  last = nil

  if input
    input_fn = lambda { input.gets(nil) }
  elsif !ARGV.empty?
    $line_mode = true if $line_mode.nil?
    input_fn = lambda {
      return nil if ARGV.empty? # no more files
      filename = ARGV.shift
      raise AtlasError.new("no such file %p" % filename, nil) unless File.exists? filename
      File.read(filename)
    }
  else
    require "readline"
    $repl_mode = true
    hist_file = Dir.home + "/.atlas_history"
    if File.exist? hist_file
      Readline::HISTORY.push *File.read(hist_file).split("\n")
    end
    input_fn = lambda {
      line = Readline.readline("\e[33m \xE1\x90\xB3 \e[0m".force_encoding("utf-8"), true)
      File.open(hist_file,'a'){|f|f.puts line} unless !line || line.empty?
      line
    }
    Readline.completion_append_character = " "
    Readline.basic_word_break_characters = " \n\t1234567890~`!@\#$%^&*()_-+={[]}\\|:;'\",<.>/?"
    Readline.completion_proc = lambda{|s|
      var_names = context.keys.reject{|k|k['_']} # hide internal vars
      all = var_names + ActualOpsList.filter(&:name).map(&:name) + Commands.keys
      all.filter{|name|name.index(s)==0}.reject{|name|name['_']}
    }
  end

  loop {
    begin
      line=input_fn.call
      break if line==nil # eof

      token_lines,line_no=lex(line, line_no)

      token_lines.each{|tokens| # each line
        next if tokens.empty?

        exe = lambda{
          if tokens.empty?
            raise ParseError.new("expecting an expression for command on line %d" % (line_no-1),nil)
          else
            last = tokens.empty? ? last : infer(to_ir(parse_line(tokens),context,last))
          end
        }

        if (command=Commands[tokens[0].str])
          tokens.shift
          command[2][tokens, exe]
        elsif !command && (command=Commands[tokens[-1].str])
          tokens.pop
          command[2][tokens, exe]
        elsif tokens[0].str=="let"
          raise ParseError.new("let syntax is: let var = value", tokens[0]) unless tokens.size > 3 && tokens[2].str=="="
          set(tokens[1].ensure_name, parse_line(tokens[3..-1]), context,last)
        else
          ir = exe.call
          puts "\e[38;5;243m#{ir.type_with_vec_level.inspect}\e[0m" if $repl_mode
          run(ir) {|v|
            to_string(ir.type+ir.vec_level,v,$line_mode)
          }
        end
      }
    rescue AtlasError => e
      STDERR.puts e.message
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
      STDERR.puts DynamicError.new("Stack Overflow Error\nYou could increase depth by changing shell variable (or by compiling to haskell todo):\nexport RUBY_THREAD_VM_STACK_SIZE=<size in bytes>", nil).message
    rescue Errno::EPIPE
      exit
    rescue => e
      STDERR.puts "!!!This is an internal Altas error, please report the bug (via github issue or email name of this lang at golfscript.com)!!!\n\n"
      raise e
    end
  } # loop
end
