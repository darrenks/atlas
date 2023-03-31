# Repl
Use the repl by just invoking Atlas from the command line without args.

Using it in non repl mode is actually very similar to just piping each line of your file into the repl. One difference is that in repl mode a list or vectors of ints/strings will print with a space between them instead of just a newline. You can still use the `print` command to see how it would print in non repl mode.

repl mode will also warn you if you use unset identifiers (which normally default to their string value or roman numeral value, e.g. `Fizz` = `"Fizz"`, `IX` = `9`). This could be useful to catch typos. So it may be worth developing from a file in repl mode on too, which can be done with the `-repl_mode` flag (and you can use the repl with `-no_repl_mode` if you wish as well).

# Debug Features

See the end of the quickref for a few useful commands for debugging.

