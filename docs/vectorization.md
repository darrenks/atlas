# Vectorization

Any list can be turned into a vector by using the `.` operator. A vector is just a list, but it prefers to apply operands to its elements instead of the list as a whole.

    "abc","123" len
    "abc","123". len
    ──────────────────────────────────
    2
    3 3

Automatic vectorization can occur to fit the type specification of an operator. For example, the type of `+` is `Int Int -> Int` and so if you give it a list for any of the arguments, their rank is too high and so it vectorizes said argument to bring it down. It is essentially performing a `map`.

    1,2,3.+4 p
    1,2,3+4 p
    ──────────────────────────────────
    <5,6,7>
    <5,6,7>

Note that the type is a vector not a list, even though `1,2,3` is a list, it was first vectorized. You can convert a vector back to a list using `%`. But usually this isn't needed because unvectorization is also automatically done if an arguments rank is too low.

    1,2,3+4% len
    1,2,3+4 len
    ──────────────────────────────────
    3
    3

If two vectors are present it pairs them off an performs the operation on each pair. It is essentially performing a `zipWith`

    (1,2,3) + (2,4,6)
    ──────────────────────────────────
    3 6 9

Longer lists are truncated to that of the smaller (this isn't the case for all vectorized languages, but useful in Atlas since we frequently use infinite lists).

    (1,2) + (2,4,6)
    ──────────────────────────────────
    3 6

Automatic vectorization can work on non scalar arguments as well.

    "1 2 3","4 5" read p
    ──────────────────────────────────
    <[1,2,3],[4,5]>

Read expects a string, but was given a list of strings so it vectorizes. Read returns a list of ints always, so that part is just normal operation.

It can even work on more complicated types like the type of append (`[a] [a] -> [a]`).

    "abc","xyz" append "123" p
    ──────────────────────────────────
    <"abc123","xyz123">

Automatic Vectorization can only lower rank, sometimes it needs to be raised. For example transpose works on 2D lists, but if you give it a 1D list it needs to become a 2D list first, by just making it a list with a single element (the original list). I call this promotion.

    "123" \ p
    ──────────────────────────────────
    ["1","2","3"]

Automatic promotion and vectorization can both be done implicitly together. For example:

    'a take (1,0) p
    ──────────────────────────────────
    <"a","">

The `(1,0)` is vectorized and the `'a` is promoted to a string.

Unvectorization is preferred to promotion. That is why the earlier example `1,2,3+4 len` returned `3` instead of `[1,1,1]`.

There is one exception to these rules which is for `,` and this is to enable intuitive list construction from data. This is how `"abc","123","xyz"` creates a list of strings. Without preferring promotion over vectorization of the first arg, `,` would need to be type `a a -> [a]` to get the first use to work and type `[a] a -> [a]` to get the second op to work as well. `,` just prefers to promote once rather than automatically vectorize the first arg, you can still vectorize that arg, you will just need to do so explicitly.
