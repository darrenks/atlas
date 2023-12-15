# Types

There are 5 types in Atlas.
-   Numbers (arbitrary precision integers and double precision floating point numbers).
-   Chars which are just integers that may have a different set of operations allowed on them including how they are displayed. Construct them using a single leading `'`.
-   Lists, which may also be of other lists. A list of a list of integers is what I call a 2D list AKA a rank 2 list. This is not a matrix, each sublist may have a different length.
-   Vectors, which are just list that prefer to apply operands to their elements instead of the list as a whole. See the [vectorization](vectorization.md) section for information about how automatic vectorization rules.
-   A, the unknown type. The empty list `()` is a list of this type.

Strings are just lists of characters.

    123 -- This is an integer
    12.3 -- This is a float
    'x -- This is a char
    "abc" -- This is a string, aka list of chars
    1,2,3 -- This is a list of integers constructed via the build operator twice.
    () p -- This is an empty list pretty printed
    ──────────────────────────────────
    123
    12.3
    x
    abc
    1 2 3
    []

Some escapes are possible in chars/strings:

`\0` `\n` `\"` `\\` `\x[0-9a-f][0-9a-f]`

You may also use any unicode character, the Atlas files are assumed to be UTF-8 encoded.

Numbers are truthy if >0, chars if non whitespace, lists if non empty. This is only used by operators like `and`, `or`, `filter`, `not`, etc.

Atlas is statically typed. Inference works in a top down fashion. You shouldn't have to think about it or even notice it since you never need to specify type. The only thing it prevents is heterogeneous lists, but there are major advantages to homogeneous lists when it comes to implicit vectorization. Homogeneous lists could be done dynamically, but static typing is useful for circular programs it allows for selecting of op behavior and vectorization before evaluating the args.

I'm very happy with how inference turned out. You will never need to specify a type or get an error message about an ambiguous type, etc. It should feel as easy as dynamic typing but with better error messages and more consistent op overloading / coercion.

Unknown needs to be it's own type (as opposed to solving a type variable like Haskell) in order for top down type inference to work (which is what Atlas uses). It becomes the smallest rank type it can when used in ops with type constraints like `append`. You may also see this type displayed as the arg type in invalid circular program's error messages, this is because the type of all values in a circular definition are considered unknown until they can be inferred. If they are never inferred their type remains unknown. It is not possible to construct program that would do anything except infinite loop or error if a value of type unknown is used, so this is not a limitation of the inference.

Doing type inference on circular programs that can have implicit vectorization was a very tricky problem to solve, and the current implementation is imperfect. There is no need to understand how it works, but I will explain it, mostly so that I can read this when I forget.

For non circular programs, inference is trivial and works in a top down fashion, but for circular programs there is nowhere to start. It starts anywhere in the circle with a guess that its arg types are type scalar unknown and recomputes the type of the resulting op, if the result is different than before it then recomputes types that depended on that recursively.

So long as there is no oscillation between types this process will eventually terminate with the smallest possible ranks for each node (or try to construct an infinite type - which is an invalid program). So how do we know no oscillation is possible? Ops are chosen to obey a couple of invariants:

-   Base elements could actually oscillate, consider the code `'b-a`, it will return an int if `a` is a char, but a char if `a` is an int. However this doesn't matter because any circular program at the scalar level would definitely be an infinite loop.
-   List rank can only increase or stay the same if their argument's list rank increase.
-   Vector rank can only increase or stay the same if their argument's vector ranks increase. And they may not change the list rank of the result. Currently the cons ops do not obey this invariant (they will automatically unvectorize if given a vector of scalars, this decreases list rank).

This last bullet is important since decreasing list rank can increase vector rank. Consider the code:

    "abcd" = 'c len p
    ──────────────────────────────────
    <0,0,1,0>

If we increase the right arg to a string:

    "abcd" = "c" len
    ──────────────────────────────────
    0

The result has the same list rank (0), but a lower vector rank. But since there is no way to convert this vector rank decrease back into a list rank decrease, it is safe. Any op that would unvectorize would also just promote if the vector rank was too low.

This invariants are chosen because changing list rank could increase the resulting vector rank (e.g. scalar ops that auto vectorize) or decrease vector rank (e.g. the equality test mentioned above).

There is also a flaw in the current inference algorithm in that it simultaneously finds the list and vector ranks, whereas it should find the list rank and then the vector rank, since the vector rank could temporarily be higher than the lowest possible while finding the minimum list ranks. In practice this flaw is very rarely encountered and could be worked around, although it would be very annoying. TODO fix it.

One could easily violate these invariants when designing op behavior and auto vectorization rules. For example suppose you created an op that removed all vectorization (2d vector would return a 2d list for example). This would violate a rule because changing vector rank would change the resulting list rank. The current `unvec` op always removes exactly 1 layer.
