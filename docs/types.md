# Types

There are 5 types in Atlas.
-   Integers (arbitrary precision).
-   Chars which are just integers that may have a different set of operations allowed on them including how they are displayed. Construct them using a single leading `'`.
-   Lists, which may also be of other lists. A list of a list of integers is what I call a 2D list AKA a rank 2 list. This is not a matrix, each sublist may have a different length.
-   Vectors, which are just list that prefer to apply operands to their elements instead of the list as a whole.
-   Nil which means a list of unknown type. This is the type of `()`, the empty list. It needs its own type in order for top down type inference to work (which is what Atlas uses). It becomes the smallest rank type it can when used in ops with type constraints like `append`. You may also see this type displayed as the arg type in invalid circular program's error messages, this is because unknown types start off as nil during inference since it can become anything.

Strings are just lists of characters.

    123 // This is an integer
    'x // This is a char
    "abc" // This is a string, aka list of chars
    1,2,3 // This is a list of integers constructed via the snoc (cons on end) operator.
    () show // This is an empty list pretty printed
    ──────────────────────────────────
    123
    x
    abc
    1 2 3
    []

Some escapes are possible in chars/strings:

`\0` `\n` `\"` `\\` `\x[0-9a-f][0-9a-f]`

You may also use any unicode character, the Atlas files are assumed to be UTF-8 encoded.

Integers are truthy if >0, chars if non whitespace, lists if non empty. This is only used by the if/else operator.

Atlas is statically typed. Inference works in a top down fashion. You shouldn't have to think about it or even notice it since you never need to specify type. The only thing it prevents is heterogeneous lists, but there are major advantages to homogeneous lists when it comes to implicit vectorization. Homogeneous lists could be done dynamically, but static typing is useful for circular programs it allows for selecting of op behavior and vectorization before evaluating the args.

Doing type inference on circular programs that can have implicit vectorization was a very tricky problem to solve, it works by treating the types as a lattice. An implication of this is that ops shouldn't be able to have a smaller rank if their arguments ranks increase. An equality op that returns 1 or 0 instead of the arg or empty violates this, hence one reason it was removed, but the current way would probably be more useful anyway.
