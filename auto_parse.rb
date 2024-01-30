require_relative "./lex.rb"
# todo package needs to sort...
SepRx = /, | |,/
BetweenRx = /#{SepRx}|#{NewlineRx}|#{SepRx}#{NewlineRx}/

def parse_input
  input = STDIN.gets(nil)||"" # todo test with other encodings
  # convert back to lazy so that we can use our lib function for parsing nums
  lazy_input = lines(str_to_lazy_list(input).const)
  # is it just numbers?
  if input =~ /\A#{NumRx}(#{BetweenRx}#{NumRx})*#{BetweenRx}?\Z/m
    read = map(lazy_input.const){|v|split_non_digits(v)}
    eager = to_eager_list(read.const).map{|a| to_eager_list(a.const) }

    if eager.size == 1 && eager[0].size == 1 # is it 1 number
      $input_value = eager[0][0]
      $input_type = Num
    elsif eager.size == 1 # is it a row
      $input_value = read[0].value
      $input_type = [Num]
    elsif eager.all?{|a|a.size == 1} # is it a col
      $input_value = map(read.const){|v|v.value[0].value}
      $input_type = v(Num)
    else # its a matrix
      $input_value = read
      $input_type = v([Num])
    end
  else # not numbers
    if input =~ /#{NewlineRx}./m # multi line
      $input_value = lazy_input
      $input_type = v(Str)
    elsif lazy_input.empty?
      $input_value = []
      $input_type = Empty
    else
      $input_value = lazy_input[0].value
      $input_type = Str
    end
  end
end