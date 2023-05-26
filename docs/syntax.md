# Syntax

Atlas uses infix syntax for all operations. It's precedence is left to right. Atlas tries to compromise between simplicity, familiarity, and conciseness. Sticking to math like precedence would be more familiar, but is actually quite complicated and inconsistent. Similar reasoning as APL is also used here in that there are too many ops to keep track of the precedence of each. It's actually very easy to get used to the lack of op specific precedence.

All ops have a symbol version and named version. This is so that code can be written in a legible way (even to newcomers) but you can also make it short if you want to. I have no idea why APL and variants don't do this. Even the named versions are still written infix. For example:

    4 add 5
    ──────────────────────────────────
    9

You can think of it like an OO languages `a.add(5)` if that helps.

Atlas is actually a just a REPL calculator and so if you have multiple lines it is just treated as multiple expressions that are all printed.

Single line comments are done with `--`. I recommend setting your syntax highlighting to be Haskell for `.atl` files for an easy keyboard shortcut. If you wanted to negate then subtract, just add then negate instead.

    1+1--this is ignored
    ──────────────────────────────────
    2


Since all ops are overloaded as both unary and binary operators if there are multiple ops in a row, the last is the binary operator and the rest are unary (it is the only way that makes sense).

    3-|+1 -- that is negate then abs value
    ──────────────────────────────────
    4

The `+` was a binary op, and the `-` and `|` are unary.

Two expressions in a row without an explicit operation do an implicit op. This uses the `build` operator.  You don't necessarily need a space to use this. This implicit operation is still left to right and equal precedence to other operations.

    1+1 3*4
    -- Is parsed as:
    ((1+1) 3)*4
    -- And does a build
    ──────────────────────────────────
    8 12
    8 12

If you want to use the implicit op following a unary op, it would look like you were trying to just do a binary op instead. To overcome this just be explicit and use `,`.

    2-,3
    -- or you could use parenthesis
    (2-)3
    ──────────────────────────────────
    -2 3
    -2 3

In addition to assignment, `=` is also used to test equality, it is only used as assignment if first on a line and the left hand side is an identifier.

`()` is the empty list.

    () p
    ──────────────────────────────────
    []

Identifiers must start with a letter but then can have numbers or underscores.

Parens do *not* need to be matched

    )p
    2*(3+4
    ──────────────────────────────────
    []
    14

`@` is an op modifier that flips the argument order of the next op. It can be used in a nested manner.

    2*1@+1@+1
    2*(1+(1+1))
    ──────────────────────────────────
    6
    6

It can also be used on unary ops. It will be done implicitly on unary ops if used on a binary op right after it.

    2*1-@+1
    2*1@-@+1
    2*((1-)+1)
    ──────────────────────────────────
    0
    0
    0

`@` is also an assignment that does not consume the value (if there is an identifier on the right).

    1+2@a*a
    ──────────────────────────────────
    9

`\` is also a modifier that flips the op order of the previous op.

    5-\8
    ──────────────────────────────────
    3

The reason for it being after the op is so that it can also be used as a regular unary op as well (`transpose`).

Both of these modifiers can be used on the implicit op.

    "hi"\"there"
    2+3@5
    ──────────────────────────────────
    there hi
    5 7

`{` and `}` may seem special syntactically, but they are not. `{` is a unary op that "pushes" on to a stack (that only exists at parse time) so that the next `}` (which is just an atom) can access the same value. It is equivalent to using assignment or `@`, but shorter when a value is reused only once. It has a nice appearance in that visually matching brackets will tell you which one corresponds to which.

    5*2{*}
    ──────────────────────────────────
    100

The curly brackets are nice for avoiding normal variable assignments, but cannot help you write a circular program since they always copy the left value. To do that just use parenthesis with an implicit value. Instead of writing `a cons 1@a` we could just write:

    (cons 1)
    ──────────────────────────────────
    1 1 1 1 1 1...

If an implicit value is used at the beginning a line it is the result of the previous line (or stdin if it is the first line).

    1+2
    -
    ──────────────────────────────────
    3
    -3
