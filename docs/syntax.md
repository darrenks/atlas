# Syntax

Atlas uses infix syntax for all operations. It's precedence is right to left. Atlas tries to compromise between simplicity, familiarity, and conciseness. Sticking to math like precedence would be more familiar, but is actually quite complicated and inconsistent. Similar reasoning as APL is also used here in that there are too many ops to keep track of the precedence of each. It's actually very easy to get used to the lack of op specific precedence.

All ops have a symbol version and named version. This is so that code can be written in a legible way (even to newcomers) but you can also make it short if you want to. I have no idea why APL and variants don't do this. Even the named versions are still written infix. For example:

    4 add 5
    ──────────────────────────────────
    9

You can think of it like an OO languages `a.add(5)` if that helps.

Atlas is actually a just a REPL calculator and so if you have multiple lines it is just treat as multiple expressions that are all printed.

    4
    1+2
    ──────────────────────────────────
    4
    3

Multiple binary operators are evaluated left to right.

    1+2*3
    ──────────────────────────────────
    9

If you want it to evaluate the right side first, use parenthesis.

    1+(2*3)
    ──────────────────────────────────
    7

You can also name expressions:

    a = 4
    a + a
    ──────────────────────────────────
    8

`=` is the only thing that will suppress the automatic printing of values, but if an assignment is the last thing in your program it too will be printed.

    a=2
    3
    b=4
    ──────────────────────────────────
    3
    4

-   `()` is the empty list.
-   Single line comments are done with `//`
-   `!`s modify an op to increase the vectorization level.
-   Identifiers must start with a letter but then can have numbers or underscores.

Since all ops are overloaded as both unary and binary operators if there are multiple ops in a row, the last is the binary operator and the rest are unary.

    3~~+1
    ──────────────────────────────────
    4

The `+` was a binary op, and the `~` are unary.

Two expressions in a row without an explicit operation do an implicit op. For numbers this multiplies, and for strings it catenates. You don't necessarily need a space to use this. This implicit operation is still left to right and equal precedence to other operations unlike APL which has a special case.

    1-2 3+4
    // Is parsed as:
    ((1-2) 3)+4
    ──────────────────────────────────
    3 7
    3 7

APL would have done `1-(2 3)+4`.

If you want to use an implicit cons and the second expression starts with a unary op, that would look like the use of a binary op, so to distinguish that case use a space before it.

    1~ 3
    ──────────────────────────────────
    -1 3

Special brackets for list construction like a sane language would be nice, but a theme of Atlas is that all ops can be one symbol, and I wish to conserve those since parenthesis work almost as well.
