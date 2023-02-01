echo 1+2 | ruby atlas > /dev/null
cat test/repl_test_input.txt | ruby atlas > test/repl_test_output.txt 2>&1
diff test/repl_test_output.txt test/repl_test_expected.txt
