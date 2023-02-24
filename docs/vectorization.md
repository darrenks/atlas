# Vectorization

Automatic vectorization is the implicit zipping or mapping of operations when the ranks of arguments are too large. This is quite useful, one of the reasons APL code is so short.

For example `+` operates on scalars (rank 0). If we give it two lists (each rank 1), it will automatically perform a zip.

    (1 2 3) + (2 4 6)
    ──────────────────────────────────
    3 6 9

Longer lists are truncated to that of the smaller (this isn't the case for all vectorized languages, but useful in Atlas since we frequently use infinite lists).

    (1 2) + (2 4 6)
    ──────────────────────────────────
    3 6

Arguments that would have been too small of a rank after zipping are automatically replicated.

    1 + (1 2 3)
    ──────────────────────────────────
    2 3 4

That code first became:

    [1,1,1,1,1...] + [1,2,3]


Explicit vectorizations are allowed too. For example head returns the first element of a list.

    "hi"; "there" head
    ──────────────────────────────────
    hi

But we can explicitly vectorize this with `.` to instead return the head of each element. It could be used repeatedly with higher ranked lists.

    "hi"; "there". head
    ──────────────────────────────────
    ht

Since implicit vectorization always happens when the operation would be ill typed without it, it is an error to also explicitly vectorize. That is because in some cases is possible that there is implicit vectorization happening, but additional explicit vectorization is still possible. For example with operands that take a scalar and an list, like take.

    "hi"; "there"; ("next"; "frog") take (1 2)
    ──────────────────────────────────
    hi
    next frog

Since the left arg of take (`(1 2)`) must be a scalar it vectorizes. Taking the first word from the first list of strings and two words from the second list of strings.

    "hi"; "there"; ("next"; "frog").. take (1 2)
    ──────────────────────────────────
    h th
    n fr

But we also could mean we wanted to do that instead.

The algorithm that decides how much vectorization to do works by finding the arg with the highest excessive rank compared to the op's type specification (since vectorization lowers rank). Any arg that would then have too low of a rank is replicated to bring it back up. This algorithm can work on ops that don't have scalar requirements (something that as far as I know APL variants can't do because they lack homogenous lists and static types). For example:

Todo update this when there is an op of type `[a] [a]->` again that doesn't prefer promotion over vectorization

It even works on `then` statements.

Vectorization can only lower rank, sometimes it needs to be raised. For example transpose works on 2D lists, but if you give it a 1D list it needs to become a 2D list first, by just making it a list with a single element (the original list). I call this promotion. Implicit cons is the only op that defaults to promotion rather than vectorization by the way.

Promotion and vectorization can both be done implicitly together. For example:

    'a [ (1 0) show
    ──────────────────────────────────
    <"a","">

This is the same as the previous example. Here the ranks differ by 2, but it cannot vectorize twice because the type of append requires a list and the first arg is a scalar, so promotion is used.

If you are ever unsure about what implicit operations are happening, run atlas with the `--debug` option and all implicit operations will be printed as explicit operations.