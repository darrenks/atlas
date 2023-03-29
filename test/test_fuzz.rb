require 'stringio'
require "./repl.rb"

symbols = "~`!@#$%^&*()_-+={[}]|\\'\";:,<.>/?"


#symbols = "~!!@@$()-=[]';?:"
numbers = "0123"
letters = "abC"
spaces = " \n\n\n\n" # twice as likely

# Just the interesting characters to focus on testing parse
# all = "[! \n()'\"1\\:?ab".chars.to_a + [':=','a:=',"seeParse","seeInference","seeType"]

all = (symbols+numbers+letters+spaces).chars+['"ab12"','p','print','help','ops','version','type']

ReadStdin = Promise.new{ str_to_lazy_list("ab12") }

# todo take all tests and make larger programs that are almost correct

n = 1000000
STEP_LIMIT = 5000

class Promise
  alias old_value value
  def value
    $reductions += 1
    raise DynamicError.new("step limit exceeded", nil) if $reductions > STEP_LIMIT
    old_value
  end
end

4.upto(8){|program_size|
  n.times{
    program = program_size.times.map{all[(rand*all.size).to_i]}*""
    program_io=StringIO.new(program)
    begin
      puts program
      $reductions = 0
      repl(program_io)
#       puts "output: ", output_io.string
    rescue AtlasError => e

    rescue => e
      STDERR.puts "failed, program was"
      STDERR.puts program
      raise e
    end
  }
}
