# Repl
Use the repl by just invoking Atlas from the command line without args.

Using it in non repl mode is actually very similar to just piping each line of your file into the repl. One key difference is that when read from a file Atlas defaults to "golf mode" and in the repl it does not. "Golf mode" can be manually forced to be on or off with `-g` or `-G`.

# Golf mode
Sets some things that would be useful for golfing, but detrimental to debugging/finding errors.

-   In golf mode unset identifiers default to being a string. E.g. if you use a variable `Fizz` without ever setting `Fizz` it will default to being the same as `"Fizz"`.
-   In golf mode list or vectors of ints/strings will print with a newline between them instead of just a space. This is usually the preferred output for most problems yet can be overly verbose reading your output easily. Higher dimension lists will print the same.

# Debug Features

The repl (and when running form a file have some helpful features):

`ops`
Returns a list of all ops and their types with examples.

`p`
Pretty prints a value (technically it turns a string rather than printing)

`type`
Returns the type of a value as a string.

`reductions`
Returns the number of reductions that Atlas has done so far, useful for measuring efficiency of your programs in a deterministic manner.

`version`
Current version of Atlas.

`<command>`
An op by itself will print all the info about that operation

