# Vectorization

Automatic vectorization is the implicit zipping of operations when the ranks of arguments are too large. This is quite useful, one of the reasons APL code is so short.

For example `+` operates on scalars (rank 0). If we give it two lists (each rank 1), it will automatically perform a zip.

    (1:2:;3) + 2:4:;6
    ──────────────────────────────────
    3 6 9

Longer lists are truncated to that of the smaller (this isn't the case for all vectorized languages, but useful in Atlas since we frequently use infinite lists).

    (1:;2) + 2:4:;6
    ──────────────────────────────────
    3 6

Arguments that would have too small of a rank after zipping are automatically replicated.

    1 + 1:2:;3
    ──────────────────────────────────
    2 3 4

That code first became:

    [1,1,1,1,1...] + [1,2,3]


Explicit vectorizations are allowed too. For example head (`[`) returns the first element of a list.

    head "hi":;"there"
    ──────────────────────────────────
    hi

But we can explicitly vectorize this with `!` to instead return the head of each element. It could be used repeatedly with higher ranked lists.

    !head "hi":;"there"
    ──────────────────────────────────
    ht

Since implicit vectorization always happens when possible, it is an error to also explicitly vectorize. That is because in some cases is possible that there is implicit vectorization happening, but explicit vectorization is still possible. For example with operands that take a scalar and an list, like take.

    (1:;2) take ("hi":;"there") : ;("next":;"frog")
    ──────────────────────────────────
    hi
    next frog

Since `(1:;2)` must be a scalar it vectorizes. Taking the first word from the first list of strings and two words from the second list of strings.

    (1:;2) !take ("hi":;"there") : ;("next":;"frog")
    ──────────────────────────────────
    h th
    n fr

But we also could mean we wanted to do that.
