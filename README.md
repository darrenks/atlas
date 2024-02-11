This information is also available at [golfscript.com/atlas](http://www.golfscript.com/atlas) look there for the quickref as well. If linking to Atlas please link to the site rather than github.

------

Atlas is an esoteric programming language designed to show off the synergy between laziness and vectorization which allow for concise _circular programming_ - an unsung but powerful technique - nothing else is even needed!

## Latest news:
None [(see all)](docs/happenings.md)

## Features

-   Purely functional
-   Lazy lists are the only data structure
-   Each op can be represented by one of the 32 ASCII symbols (e.g. `#` `$`, etc.) and also by name
-   No control structures or way to create functions
-   Statically typed - but no need or way to specify type
-   Minimal basis rivaling the SK calculus possible
-   Left to right infix notation
-   Concise despite simplicity
-   Not practical

## Example

This page is intended to give you an overview of the main ideas while being easy to understand. Here's an example of the power of the language without such a limitation:

    1:101{,%3@5~^Fizz@,Buzz_|a
    ──────────────────────────────────
    1
    2
    Fizz
    4
    Buzz
    Fizz
    7
    8
    Fizz
    Buzz
    11
    Fizz
    13
    14
    FizzBuzz
    16
    ...

And no, those brackets are not a block but their own instructions (push, pop).

## Intro

### Vectorization

Atlas is vectorized, this means that operations performed on vectors (which are just lists) do that operation to each element.

    1,2,3.-
    ──────────────────────────────────
    -1 -2 -3

Here we see that a list was constructed with `,`'s, then it was turned into a vector with `.` and then negated with `-`. Then implicitly printed nicely with a space between each number.

It may seem odd that the `-` is postfix, but evaluation for all ops is left to right.

Vector is a separate type from list to allows ops that take arbitrary types to know which depth to vectorize at. For example, does `head` on a list of lists mean to take the first element of the whole list or the first element of each list? It would mean the former, you would use a vector of lists for the latter.

Atlas also can auto vectorize, meaning that an arg is automatically converted to a vector when an op receives a higher rank (list nest depth) type then what they expect. So we could have just written:

    1,2,3-
    ──────────────────────────────────
    -1 -2 -3

This also works with binary ops, repeating a non-vector arg as needed:

    (1,2,3)+(4,5,6)
    (1,2,3)+2
    ──────────────────────────────────
    5 7 9
    3 4 5

You can always explicitly do these things but as you gain more experience it may be worth better understanding when it can be left implicit. For more on vectorization, check the [vectorization doc](docs/vectorization.md).

### Laziness

Atlas is also lazy, this means that values are not computed if they are not used, even individual elements of a list. This is possible because there are no operations that cause side effects.

One huge benefit of laziness is that streams and lists can be unified to a single data type. For example, `input` refers to stdin and is like a stream in a normal language, but in Atlas it is a regular value.

    input + 1

Just adds 1 to each character you input (`a` becomes `b` etc.), as you input it, for any number of lines.

For more information on laziness check [wikipedia](https://en.wikipedia.org/wiki/Lazy_evaluation) or try out Haskell.

### Circular Programming

Circular programming is the use of a value before it has been computed. It is something that you cannot do in an eager language. The simplest example would be this:

    let a=1_a
    a
    ──────────────────────────────────
    1 1 1 1 1 1 1 1 1 1 1 1 1...

That list is infinite but truncated for display purposes. We are just saying that `a` is 1 prepended to `a`. You could think of `a` as a recursive function that takes no arguments and memoizes its result. `a` is infinite but only takes a constant amount of memory.

Infinite lists are no problem so long as we don't try to access all elements, that would be an infinite loop.

Let's see a more complicated example:

    let a=0_(a+1)
    a
    ──────────────────────────────────
    0 1 2 3 4 5 6 7 8 9 10 11 12...

How does it work? It is just saying that `a` is 0 prepended to the vectorized addition of `a` and 1, so the next element would be 0+1 and the next 1 more than that and so on.

We can even compute the fibonacci sequence this way:

    let f=1_1_(f tail+f)
    f
    ──────────────────────────────────
    1 1 2 3 5 8 13 21 34 55 89...

An example of this in Haskell was my first exposure to circular programming, and at first I just dismissed it as some special case magic. But there is no special case, neither Haskell nor Atlas treat that code any differently than a non-circular program, it just computes list elements lazily like always.

This technique of circular programming is legitimately useful and often the simplest and most efficient way to describe sequences in lazy languages.

FYI circular programming can also refer to using tuples in a circular manner (this is actually the more common usage of the term), but Atlas does not have tuples and this technique is less mind blowing. [Here is a tutorial on that in Haskell](http://www.cs.umd.edu/class/spring2019/cmsc388F/assignments/circular-programming.html).

### Folding

Circular programming can be used to do a scan or a fold. Here is an example of that:

    let x=1,2,3,4,5
    let a=0_(x+a)
    a
    ──────────────────────────────────
    0 1 3 6 10 15

Here's how it works:

    x:       1  2  3  4  5
    a:       0  1  3  6  10  15
    x+a:     1  3  6  10 15
    0_(x+a): 0  1  3  6  10  15

We can see that `x+a` computes the next prefix sum if the previous values of `a` are the previous prefix sums. So by starting from 0 and using induction it works.

A scan by any function can be computed this way, a fold would just be taking the last element of the result.

Experienced functional programmers may notice this is a scanl/foldl. There are some cases where a foldr would be more useful because it may terminate a "loop" early, for example if you wanted to check if all elements of a list are truthy but stop as soon as you find a falsey element. Interestingly, a foldr is possible too, check out the [doc on circular programming](docs/circular.md) to see how that works.

## Beyond

At this point you know enough to play with Atlas and practice circular programming. The implications of these concepts have depth beyond what this intro has covered and Atlas does have a few more features that you might want to learn if you want to start writing more complicated or succinct programs. Check out the docs for more info.
