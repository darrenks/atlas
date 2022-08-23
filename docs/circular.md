# Circular Programming

Let's cut straight to the most real-world educational bit of this tutorial. What is Circular Programming? It is the technique of using the result of an operation as an argument to itself. In a strict language this wouldn't make any sense, but in a lazy language it can actually be quite useful and efficient.

The first example I saw of circular programming was the definition of fibonacci numbers in Haskell:

    fibs = 1 : 1 : zipWith (+) fibs (tail fibs)

If you are unfamiliar with Haskell syntax, this basically means 1 prepended to 1 prepended to the elementwise addition of fibs and fibs[1..]

Not only is this definition succinct but it is also fast (linear number of additions).

Initially, I didn't pay much attention to it and just assumed it was some special case gimmick semi-hard-coded into Haskell. But actually there is no special case. Here is how it works:

First let's rewrite it as:

    z = zipWith (+) (1:z) (1:1:z)
    fibs = 1 : 1 : z

Now remember that Haskell is [lazy](https://en.wikipedia.org/wiki/Lazy_evaluation), so it doesn't do anything unless we ask about elements. When we ask for elements from z they are computed. It's easy to see that the first element of z is 2. But when we ask for the next it is going to be 1 + head z. And by now we know the head of z, it is 2. So the answer is 3. Next it will be the sum of the 2nd and 3rd elements of z which is 5. The confusing thing about this is how it can it reference z before it is defined? The other key thing to remember about Haskell is it is static and this is a definition not a statement that is executed.

Here's another way of looking at it. It's like z is actually a recursive function that takes no arguments. When we see recursive function definitions, we are not confused at all, so consider this definition of a function for z.

    z() = zipWith (+) (1:(z())) (1:1:(z()))

It's still relying on laziness to treat the result like a stream, but there is no circular definition of values, only a recursive function definition.

It is also computes the fibonacci numbers. The base cases work and so does the inductive step so therefore it is correct. But it is exponentially slower, because it computes z() twice rather than using the same value. This could be fixed with an assignment:

    z() = let ze = z() in zipWith (+) (1:ze) (1:1:ze)

But what is the point of making z a function, it doesn't use its argument? Functions without arguments **ARE** values! Just define z as a value and we end up with the code we started with.

Laziness will not save the day from all circular programs, only so long as we do not ask for a value in a circle before it has been computed. If we had said a = a+1 we would hit an infinite loop. What is "a"? It is a+1, and what is "a"? It is a+1, etc.

There's [another powerful use of circular programming](http://www.cs.umd.edu/class/spring2019/cmsc388F/assignments/circular-programming.html), but it isn't really applicable in Atlas.

In Atlas1d that program would be written as

    fibs = : 1 : 1 + fibs tail fibs

The zip is implicit via vectorization, the `:` and `+` are prefix not infix, and the parens are unneeded since arity is known for all functions and no partial function application is allowed - this is also known as [Polish notation](https://en.wikipedia.org/wiki/Polish_notation).

In Atlas it would be (2d):

     1
     v
     @>:<+<@
       v ^ ^
     1 .>@ ^
     v v   ^
     @>:   ^
       v   ^
       .>>>@
       v
       o

which represents this graph:

     1
     ╰→ : ← + ←╮
        │   │  │
        ├───╯  │
     1  │      │
     ╰→ :      │
        │      │
        ├──────╯
        │
        o


This program duplicates the cons (`:`) at different spots rather than using the same one and then taking the tail.

Atlas is somewhat smart about deducing connections without arrows, that program could have been golfed a bit and written as:

    1:<@
     .>+
    1:.@
      o

That's probably the perfect use of circular programming, but there are many other uses too, and you can do almost anything you'd want using just it and the `last` operator. Examples in the cookbook.
