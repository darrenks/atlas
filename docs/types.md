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
    1,2,3 -- This is a list of integers constructed via the snoc (cons on end) operator.
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

Doing type inference on circular programs that can have implicit vectorization was a very tricky problem to solve - although the code to implement it is very simple, it works by treating the types as a lattice. There is no need to understand how it works, but I will explain it, mostly so that I can read this when I forget.

For non circular programs, inference is trivial and works in a top down fashion, but for circular programs there is nowhere to start. It starts anywhere in the circle with a guess that its arg types are type unknown and recomputes the type of the resulting op, if the result is different than before it then recomputes types that depended on that recursively.

So long as there is no oscillation between types this process will eventually terminate or try to construct an infinite type (which is invalid). This is what I meant by it being a lattice. So how do we know no oscillation is possible?

-   Base elements could actually oscillate, consider the code `'b-a`, it will return an int if `a` is a char, but a char if `a` is an int. However this doesn't matter because any circular program at the scalar level would definitely be an infinite loop.
-   List depth can only increase or stay the same if their argument's list depth increase.
-   Vector depth can only increase or stay the same if their argument's vector depth increase. And decreasing the vector depth cannot decrease list depth.

This last point is important since decreasing list depth can increase vector depth. Consider the code:

    "abcd" = 'c len p
    ──────────────────────────────────
    <0,0,1,0>

If we increase the right arg to a string:

    "abcd" = "c" len
    ──────────────────────────────────
    0

The result has the same list depth (0), but a lower vector depth. But since there is no way to convert this vector depth decrease back into a list depth decrease, it is safe. Any op that would unvectorize would also just promote if the vector depth was too low.

One could easily violate these lattice properties when designing op behavior and auto vectorization rules. For example suppose you created an op that removed all vectorization (2d vector would return a 2d list for example). This would violate a rule. The current `unvec` op always removes exactly 1 layer. It might be worthwhile to even create tests that none of the ops can violate the rules. If you ever do encounter a program that oscillates it will give you a special error asking you to report the bug, please do so!
