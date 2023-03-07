require './test/check_example.rb'

pass=0
OpsList.each{|op|
  (op.examples+op.tests).each{|example|
    check_example(example){
      "example test for op: #{op.name}"
    }
    pass+=1
  }
}
puts "PASS #{pass} op examples"
