require 'stringio'
require "./repl.rb"

symbols = "~`!@#$%^&*()_-+={[}]|\\'\";:,<.>/?"


#symbols = "~!!@@$()-=[]';?:"
numbers = "0123"
letters = "abC"
spaces = " \n\n\n\n" # twice as likely

# Just the interesting characters to focus on testing parse
# all = "[! \n()'\"1\\:?ab".chars.to_a + [':=','a:=',"seeParse","seeInference","seeType"]

all = (symbols+numbers+letters+spaces).chars+['"ab12"']

ReadStdin = Promise.new{ str_to_lazy_list("ab12") }

# todo take all tests and make larger programs that are almost correct

n = 1000000
step_limit = 1000

4.upto(8){|program_size|
  n.times{
    program = program_size.times.map{all[(rand*all.size).to_i]}*""
    program_io=StringIO.new(program)
    begin
      puts program
      repl(program_io,step_limit)
#       puts "output: ", output_io.string
    rescue AtlasError => e

    rescue => e
      STDERR.puts "failed, program was"
      STDERR.puts program
      raise e
    end
  }
}
