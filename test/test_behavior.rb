require "./test/check_example.rb"

line = 1
pass = 0
behavior_tests = File.read("./test/behavior_tests.atl").lines.to_a
example_regex = /^ *# ?Test: */
example_tests = File.read("ops.rb").lines.grep(example_regex).map{|line|line.gsub(example_regex,"")}
(behavior_tests + example_tests).map{|test|
  (line+=1; next) if test.strip == "" || test =~ /^\/\//
  check_example(test,line){
    "behavior test line %d" % [line]
  }
  pass += 1
  line += 1
}

puts "PASS %d behavior tests" % pass
