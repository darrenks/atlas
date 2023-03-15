cat test/golf_test_input.txt | ruby atlas -g > test/golf_test_output.txt 2>&1
diff test/golf_test_output.txt test/golf_test_expected.txt
