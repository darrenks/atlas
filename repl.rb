# -*- coding: ISO-8859-1 -*-
# Set ruby file coding (with top comment) and IO to operate on bytes.
# This is done so that everything is simply bytes in Atlas, but will display
# properly even if using fancy unicode chars in another encoding (lengths/etc will be off though).
# It is important for all encodings to match otherwise will get runtime errors when using
# fancy characters.
Encoding.default_external="iso-8859-1"
Encoding.default_internal="iso-8859-1"
require "readline"

Dir[__dir__+"/*.rb"].each{|f| require_relative f }

def repl(input=nil)
  context={}
  saves = []

  bof = Token.new("bof")
  context["last_ans"]=to_ir(AST.new(Ops0['input'],[],bof),context,saves)
  last=AST.new(Var,[],Token.new("last_ans"))
  line_no = 1

  if input
    input_fn = lambda { input.gets(nil) }
  elsif !ARGV.empty?
    input_fn = lambda { ARGV.empty? ? nil : File.read(ARGV.shift) }
  else
    $repl_mode = true if $repl_mode.nil?
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

  file_args = !ARGV.empty?
  loop {
    prev_context = context.dup
    begin
      line=nil
      line=input_fn.call
      break if line==nil # eof

      token_lines,line_no=lex(line, line_no)
      if $raw_input_mode.nil? && token_lines.size > 0
        if token_lines[0][0].str == "}"
          token_lines[0].shift
          $raw_input_mode = true
        else
          $raw_input_mode = false
        end
      end

      token_lines.each{|tokens| # each line
        next if tokens.empty?

        if (command=Commands[tokens[0].str])
          tokens.shift
          command[2][tokens, last, context, saves]
        elsif !command && (command=Commands[tokens[-1].str])
          tokens.pop
          command[2][tokens, last, context, saves]
        elsif tokens[0].str=="let"
          raise ParseError.new("let syntax is: let var = value", tokens[0]) unless tokens.size > 3 && tokens[2].str=="="
          ast = parse_line(tokens[3..-1], last)
          set(tokens[1], ast, context, saves)
        else
          ir = to_ir(parse_line(tokens, last),context,saves)
          context["last_ans"]=ir
          infer(ir)
          puts "\e[38;5;243m#{ir.type_with_vec_level.inspect}\e[0m" if $repl_mode
          run(ir) {|v|
            to_string(ir.type+ir.vec_level,v,$repl_mode||$doc_mode)
          }
        end
      }
    rescue AtlasError => e
      STDERR.puts e.message
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
      context = prev_context
    rescue Errno::EPIPE
      exit
    rescue => e
      STDERR.puts "!!!This is an internal Altas error, please report the bug (via github issue or email name of this lang at golfscript.com)!!!\n\n"
      raise e
    end
  } # loop
end
