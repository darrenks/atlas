`echo "O ) I" > test/functional_test.atl`
out = `echo hello | ruby atlas.rb test/functional_test.atl 2> /dev/null`
if out != "ello\n"
  puts "FAIL functional test"
  puts out
else
  puts "PASS functional test"
end