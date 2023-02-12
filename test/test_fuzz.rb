require 'stringio'
require "./repl.rb"

symbols = "~`!@#$%^&*()_-+={[}]|\\'\";:,<.>/?"


#symbols = "~!!@@$()-=[]';?:"
numbers = "012"
letters = "abCFS"
spaces = "  \n\n" # twice as likely

# Just the interesting characters to focus on testing parse
# all = "[! \n()'\"1\\:?ab".chars.to_a + [':=','a:=',"seeParse","seeInference","seeType"]

all = (symbols+numbers+letters+spaces).chars-['$'].to_a # remove things that get input since they stall for now

# todo take all tests and make larger programs that are almost correct

n = 100000
step_limit = 1000

1.upto(8){|program_size|
  n.times{
    program = program_size.times.map{all[(rand*all.size).to_i]}*""
    program_io=StringIO.new(program)
    output_io=StringIO.new
    begin
      repl(program_io,output_io,step_limit)
    rescue AtlasError => e

    rescue => e
      STDERR.puts "failed, program was"
      STDERR.puts program
      raise e
    end
  }
}
