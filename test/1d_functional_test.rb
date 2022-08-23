`echo "O ) I" > test/1d_functional_test.a1d`
out = `echo hello | ruby atlas.rb test/1d_functional_test.a1d 2> /dev/null`
if out != "ello\n"
  puts "FAIL 1d functional test"
  puts out
else
  puts "PASS 1d functional test"
end