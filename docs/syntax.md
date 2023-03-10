# Syntax

Atlas uses infix syntax for all operations. It's precedence is left to right. Atlas tries to compromise between simplicity, familiarity, and conciseness. Sticking to math like precedence would be more familiar, but is actually quite complicated and inconsistent. Similar reasoning as APL is also used here in that there are too many ops to keep track of the precedence of each. It's actually very easy to get used to the lack of op specific precedence.

All ops have a symbol version and named version. This is so that code can be written in a legible way (even to newcomers) but you can also make it short if you want to. I have no idea why APL and variants don't do this. Even the named versions are still written infix. For example:

    4 add 5
    ──────────────────────────────────
    9

You can think of it like an OO languages `a.add(5)` if that helps.

Atlas is actually a just a REPL calculator and so if you have multiple lines it is just treated as multiple expressions that are all printed.

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

Even unary ops go from left to right, so to negate a number you actually put the `-` after the expression to negate.

    1-
    1+2-
    ──────────────────────────────────
    -1
    -3

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

`=` is also used to test equality, it is only used as assignment if first on a line and the left hand side is an identifier.

-   `()` is the empty list.
-   Single line comments are done with `--`
-   Identifiers must start with a letter but then can have numbers or underscores.
-   `@` is an op modifier that flips the argument order.

Since all ops are overloaded as both unary and binary operators if there are multiple ops in a row, the last is the binary operator and the rest are unary.

    3-|+1 -- that is negate then abs value
    ──────────────────────────────────
    4

The `+` was a binary op, and the `-` are unary.

Two expressions in a row without an explicit operation do an implicit op. For numbers this multiplies, and for strings it catenates. You don't necessarily need a space to use this. This implicit operation is still left to right and equal precedence to other operations.

    1+2 3*4
    -- Is parsed as:
    ((1+2) 3)*4
    -- And does an implict multiplication
    ──────────────────────────────────
    36
    36

If you want to use the implicit op following a unary op, it would look like you were trying to just do a binary op instead. To overcome this just be explicit and use `*` or `_`.

    2-*3
    -- or
    (2-)3
    ──────────────────────────────────
    -6
    -6
