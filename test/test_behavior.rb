require "./test/check_example.rb"

line = 1
pass = 0
behavior_tests = File.read("./test/behavior_tests.atl").lines.to_a
behavior_tests.map{|test|
  (line+=1; next) if test.strip == "" || test =~ /^--/
  check_example(test){
    "behavior test line %d" % [line]
  }
  pass += 1
  line += 1
}

puts "PASS %d behavior tests" % pass
