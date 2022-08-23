This is TODO

the general idea is that the only type could be list and you could get rid of most ops and numbers (like the Lambda Calculus).

and that you could have unary numbers by creating lists of size n. (You could also use binary if you cared about efficiency by having lists of bits).

You can build scan like operations using circular programming.

Then you can build folds by taking the last (hence why `last`) is part of the basis.

You only need `head` `tail` `cons` `if` for this.

Note that you could have an op `uncons` that performs `if` `head` `tail` all in 1. You could also build an op that does all of the operations in 1, but that would just be silly.

In 2d you could implement `#` by consing and then taking it apart. You can probably achieve the affect of the arrows easily too, but I'd be surprised if you could eliminate spaces and you definitely can't eliminate newlines.

See the [cookbook](cookbook.md) for recipes on filter/recursion/etc.
