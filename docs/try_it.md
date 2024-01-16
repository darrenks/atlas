# Try it!

You can download the source from github or <a href="atlas" download>packaged as one file</a>. Then to start the repl, run:

    atlas

To run from a file:

    atlas filename.atl

You will need Ruby, I have tested it to work with 2.7 and 3.1.

## Repl

Using it in non repl mode is actually very similar to just piping each line of your file into the repl. One difference is that in repl mode a list or vector of ints/strings will print with a space between them instead of a newline. You can still use the `print` command to see how it would print in non repl mode.

repl mode will also add a few extra warnings, so it may be worth developing from a file with repl mode on too, which can be done with the `-repl_mode` flag (and you can use the repl with `-no_repl_mode` if you wish as well).

# Debug Features

These commands may be useful for debugging:

-   `help` see op's info (`help +`)
-   `version` see atlas version
-   `type` see expression type (`type 1+2 -> Num`)
-   `p` pretty print value (`p 1,2 -> [1,2]`)
-   `print` print a value as it would be done implicitly in file mode