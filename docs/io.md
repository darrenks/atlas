# IO

As a pure language, Atlas has no operators for doing input or output, however it is fairly easy to accomplish these tasks.

## Output

Since an Atlas program is essentially the same as typing it into a REPL. Each line is printed as it is defined. Assignments are not printed (unless it is the last line in a program). Before printing values they are first converted to strings by first joining with spaces, then newlines then double newlines depending on list depth.

Infinite list will print until they error.

## Input

The `$` token is stdin as a vector of strings, where each vector element is one line of input. Since Atlas is lazy you can accomplish interactive IO even though `$` is just a regular value.

One note about lazy IO is that it will output anything as soon as it can, so if you wanted to write a program that asked for you name and then said hello to you:

    "Enter your name: "
    "Hello, " ($% head)

Would print the hello before you typed anything because that will always precede whatever you input.

One way around that is to trick laziness into thinking the hello depends on your input. A simple but hacky way is to reverse the result twice.

    "Enter your name: "
    "Hello, " ($% head) reverse reverse

Simpler would be to just write

    "Enter your name: "
    "Hello, " $

That won't prematurely print hello, because you could input 0 lines and the implicit append operation is vectorized (since $ is a vector) and so it would say hello to however many names (lines) you input, possibly 0.

## Ints

To get ints just use the `read` op (`&`) on `$`.

## Shorthand

There is currently a shorthand for getting a column of ints from stdin and that is to use an unmatched `}`. This feels a bit hacky so I may remove it, but it is highly useful for the repetitive task of parsing input.
