# Types

There are 4 types in Atlas.
-   Integers (arbitrary precision).
-   Chars which are just integers that may have a different set of operations allowed on them including how they are displayed. Construct them using a single leading `'`.
-   Lists, which may also be of other lists. Construct them by creating an empty list with `$` and then add things to them with cons (`:`) (or create a single element list more concisely with just `;`).
-   Nil which means a list of unknown type. It will become the smallest rank type it can when used in ops with type constraints like cons. This is also the type of circular code that could be any type. E.g. `a=a`. It is the type of the empty list which is different than Haskell, it allows for purely top down type inference which I find more intuitive since it more closely resembles how types work in dynamic languages.

Strings are just lists of characters.

-   `123` this is an integer
-   `'x` this is char of the letter x
-   `"abc"` this is a string
-   `1:2:3:$` this is the list [1,2,3]

Some escapes are possible in chars/strings:

`\0` `\n` `\"` `\\` `\x[0-9a-f][0-9a-f]`

You may also use any unicode character the Atlas files are assumed to be UTF-8 encoded.

Integers are truthy if >0, chars if non whitespace, lists if non empty. This is only used by the if/else operator.

Atlas is statically typed. Inference works in a top down fashion. You shouldn't have to think about it or even notice it since you never need to specify type. The only thing it prevents is heterogeneous lists, but there are major advantages to homogeneous lists when it comes to implicit vectorization. Homogeneous lists could be done dynamically, but static typing is useful for circular programs it allows for selecting of op behavior and vectorization before evaluating the args.

Doing type inference on circular programs that can have implicit vectorization was a very tricky problem to solve, it works by treating the types as a lattice. An implication of this is that ops shouldn't be able to have a smaller rank if their arguments ranks increase. An equality op that returns 1 or 0 instead of the arg or empty violates this, hence one reason it was removed, but the current way would probably be more useful anyway.
