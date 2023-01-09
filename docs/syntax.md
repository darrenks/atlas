# Syntax

Atlas uses infix syntax for all operations. It's precedence is right to left. Atlas tries to compromise between simplicity, familiarity, and conciseness. Sticking to math like precedence would be more familiar, but is actually quite complicated and inconsistent. Similar reasoning as APL is also used here in that there are too many ops to keep track of the precedence of each. Assignment and unary ops are more intuitive right to left, and so that is why that direction is chosen. It's actually very easy to get used to. I have a plan to allow spacing to affect precedence which should make things more intuitive.

All ops have a symbol version and named version. This is so that code can be written in a legible way (even to newcomers) but you can also make it short if you want to. I have no idea why APL and variants don't do this. Even the named versions are still written infix. For example:

    4 add 5
    ──────────────────────────────────
    9

You can think of it like an OO languages `a.add(5)` if that helps.

Your program is a list of lines, any lines that do not begin with an assignment are implicitly printed.

    4
    a=3
    5
    ──────────────────────────────────
    4
    5

If there are none, then the last assignment is printed.

    a=3
    b=4
    ──────────────────────────────────
    4


-   Parenthesis work in the usual way.
-   `()` is the empty list.
-   Single line comments are done with `//`
-   `!`s modify an op to increase the vectorization level.
-   Identifiers must start with a letter but then can have numbers or underscores.

Since ops are overloaded as both unary and binary operators if there are multiple ops in a row, the first is the binary operator and the rest are unary.

    1+~~3
    ──────────────────────────────────
    4

The `+` was a binary op, and the `~` are unary.

Two expressions in a row are an implicit cons. You don't need a space to use this, but if you want to vectorize it you will need a space after the `!` for now. This implicit cons is still right to left precedence unlike APL which has a special case.

    1+2 3+4
    // Is parsed as:
    1+(2 (3+4))
    ──────────────────────────────────
    3 8
    3 8

APL would have done `1+(2 3)+4`.

If you want to use an implicit cons and the second expression starts with a unary op, that would look like the use of a binary op, so to distinguish that case use a space before it.

    1 ~3
    ──────────────────────────────────
    1 -3

Implicit cons is just a regular op. When we see things like

    (1 2 3) (4 5 6)
    ──────────────────────────────────
    1 2 3
    4 5 6

Which constructs a 2D list, it works because this op promotes its arguments to a singleton list if they match rank. `1 2 3` is `1 (2 3)`. Each `2` and `3` become lists of one element (their ranks match) and are appended. Then `1` becomes a list (to match) and is prepended. Similarly for the `4 5 6`. Now the two larger lists are implicitly consed but since they match rank they are first made a singleton 2D lists. The parenthesis do not do anything special here, they only affect precedence as usual. That's why the second set of parenthesis isn't actually needed:

    (1 2 3) 4 5 6
    ──────────────────────────────────
    1 2 3
    4 5 6

I like this simple way of creating lists, but there is one not-so-pretty case which is creating a list of 1 element. `(2)` does not work since parenthesis are just for precedence, it would be contrived to make that work because surely we don't want it to work for something like `(1+2)` used in a larger expression. To do it, just cons it with an empty list.

    show 1$
    ──────────────────────────────────
    [1]

Special brackets for list construction like a sane language would be nice, but a theme of Atlas is that all ops can be one symbol, and I wish to conserve those since parenthesis work almost as well.
