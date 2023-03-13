# Atlas

Atlas is an [esolang](https://esolangs.org/) that was created to show off the awesome synergy between circular programming and vectorization. It is purely functional but has no functions and little need for them. It has APL like syntax and vectorization without forcing you to use symbols or weird characters. It isn't intended to be good at [code golf](https://en.wikipedia.org/wiki/Code_golf), yet it is actually more succinct than Golfscript and J / K for the average code golf problem - despite its emphasis on simplicity and similar character restraints.

Currently Atlas is in Alpha. It is very usable and probably has all the important features it will ever have. But it may experience breaking changes and minor improvements. The current interpreter is slow and limited in stack depth (although fine for most toy problems). There is nothing preventing it from being compiled and stackless, it could be as fast as Haskell.

This page will show off some of the cool things about Atlas and some circular programming tricks that I have not seen anywhere else - which are applicable to other lazy languages like Haskell. For complete information about the language see the [docs folder](docs/).

You can run code by downloading the Atlas source and saving your Atlas code to a file then running:

    atlas filename.atl

Or you can use it as a repl with:

    atlas

You will need Ruby, I have tested it to work with 2.7 and 3.1.

There is also an [online REPL](https://replit.com/@darrenks/Atlas) available.

## Prerequisites to Cool Stuff

Atlas is like a calculator, all it has are values to which you can apply operators.

    1+2
    ──────────────────────────────────
    3

Syntax is also like a calculator, left to right.

    2*3+4
    ──────────────────────────────────
    10

1-arg operators go on the right.

    2-
    ──────────────────────────────────
    -2

It also has assignment.

    a=5
    a*a
    ──────────────────────────────────
    25

Unlike most calculators, it supports lists and strings (which are just a list of characters).

    1,2,3
    "abc"
    ──────────────────────────────────
    1 2 3
    abc

Operations that need a lower rank (list depth) for an argument automatically vectorize. Vectors perform operations to all elements.

    1,2,3 + (3,2,1)
    "abc" + 1
    ──────────────────────────────────
    4 4 4
    bcd

For operations that are flexible about the rank they apply to such as `head` (which returns the first element of a list) it could be useful to manually vectorize with `.` (or unvectorize with `%`) to adjust the depth the op is applied at.

    a="abc","xyz"
    a head
    a. head
    a.%head
    ──────────────────────────────────
    abc
    ax
    abc

## Circular Programming Intro

Let's look at the first example I ever saw of circular programming. It was the Haskell program:

    a = 1 : 1 : zipWith (+) (tail a) a

Which generates the infinite list of fibonacci numbers. In Atlas this would be:

    a = 1 _ 1 _ (a tail + a)
    ──────────────────────────────────
    1 1 2 3 5 8 13 ...

The only real difference between Atlas and Haskell here is that the zipWith is implicit because Atlas is vectorized.

The first time I saw this, I just dismissed it as some weird special case trick that I didn't understand and assumed it wasn't practical, but actually it isn't a trick and it is useful, it is probably the most efficient way to compute the Fibonacci numbers sequence in Haskell.

If we do not want an infinite list, we could just take the first n elements of the list and we can do so without an infinite loop, since we never ask for an infinite number of elements.

    a = 1 _ 1 _ (a tail + a)
    a take 10
    ──────────────────────────────────
    1 1 2 3 5 8 13 21 34 55

The `take` syntax is different than Haskell's, in Atlas all functions are treated as operators, since `take` has two arguments it goes between its operands like other binary operators such as `+`. There are symbol versions of all named functions, but this page's goal is to teach concepts and so will not expect you to know them.

How does it work? First remember that Atlas and Haskell are [lazy](https://en.wikipedia.org/wiki/Lazy_evaluation), so they don't do anything until we ask about the elements of `a`. Atlas starts asking for the elements of `a` in order so that it can print them. It is easy to see that the first 2 elements are 1 without needing to know the rest. The third element is the result of a `zipWith` and is computed only using the first two elements, which we already know. `zipWith` starts moving through these lists as they are generated creating an infinite list.

If this is explanation of fibonacci numbers is still confusing, here's another way of looking at it. It's like `a` is actually a recursive function that takes no arguments. Consider this definition of a function for `a` in Haskell.

    a() = 1:1:zipWith (+) (a()) (tail(a()))

It's still relying on laziness to treat the result like a stream, but there is no circular definition of values, only a recursive function definition.

It is also computes the fibonacci numbers. The base cases work and so does the inductive step so therefore it is correct. But it is exponentially slower, because it computes `a()` twice rather than using the same value. This could be fixed with an assignment:

    a() = let a2 = 1:1:a() in zipWith (+) a2 (tail a2)

But what is the point of making `a` a function, it doesn't use its argument? Functions without arguments **ARE** values in a pure language! Just define `a` as a value and we end up with the code we started with.

Laziness will not save the day for all circular programs, only so long as we do not ask for a value in a circle before it has been computed. If we had said `a = a+1` we would hit an infinite loop in Haskell when we ask for the value of `a`. What is `a`? It is `a+1`, and what is `a`? It is `a+1`, etc. Note that this would actually give a type error in Atlas but if you got around that it would raise an infinite loop error since it would also detect the circular dependency at runtime. Circular dependencies of values can always be detected at runtime but not all infinite loops can be since there are other ways to create them (that would break the halting problem).

Before we go deeper, I'd like to mention that circular programming seems to refer to two different types of things that are related. We will be exclusively talking about the kind you can do by zipping, but there is another type that involves using tuple return values seemingly before they are computed. It is worth knowing about, but not applicable in Atlas.
[Here is a tutorial](http://www.cs.umd.edu/class/spring2019/cmsc388F/assignments/circular-programming.html) on that.

### Scanl

Generating streams that depend on past values of a sequence is probably the most common use of circular programming, but what else can it do?

We can use it to calculate the scanl of a list and any operation! Suppose we had the list `1,2 3,4` and we wanted to calculate the prefix sums. Of it (e.g. `1,3,6,10`).

We can do that like this:

    a=1,2,3,4
    b=0_b+a
    ──────────────────────────────────
    1 3 6 10

And this works in Haskell too:

    a=[1,2,3,4]
    b=zipWith (+) a (0:b)

It works much the same way as the fibonacci sequence. The first element is the first element of `a` + 0, the second is the result of that + the next element in `a`.

And we can do a foldl simply be getting the last element of the scanl:

    a=1,2,3,4
    b=0_b+a
    b last
    ──────────────────────────────────
    10

Having the ability to support functions and just have built-ins for things like scan and foldr would clearly make the language more succinct, but one of the whole reasons for Atlas existence is to force you to learn circular programming and to be extremely simple.

BTW we can easily generate the list of natural numbers using this technique.

    nats=1_(1+nats)
    ──────────────────────────────────
    1 2 3 4 5 ...

And we can also create repeated numbers:

    ones=1_ones
    ──────────────────────────────────
    1 1 1 1 ...

Or sequences (this is known as also known as tying the knot).

    a=0_b
    b=1_a
    ──────────────────────────────────
    1 0 1 0 1 0 1 0 ...

But it could have just been done in one line.

    b = 1 _ 0 _ b
    ──────────────────────────────────
    1 0 1 0 1 0 1 0 ...

## Foldr

A foldr is more useful than a foldl because it can lazily terminate. It also doesn't require a function `last` to be written for us in order to achieve it, which is of theoretical interest for creating a small basis for this language. In fact we can implement `last` using a foldr.

Suppose you wanted to see if any elements in a list were falsey. That is essentially a fold on a logical AND. But with a foldl we can't lazily terminate when we find one. However a foldr is like getting the first element of a scanr and will lazily terminate as soon as one is found.

When first exploring the ideas of this language I didn't think it was possible to scanr or foldr with just basic head/tail ops. I was really blown away when I discovered how to. It can actually be done in much the same way as scanl, but with a bit of extra care.

To sum via scanr we want the last element to be last element of the original list + 0, and the 2nd to last to be the sum of the last 2 numbers + 0 and so on. So in Haskell it seems we could just write the Haskell code:

    a = [1,2,3,4]
    b = zipWith (+) a (tail (b++[0]))

Another way to think of it is the first element is the sum of the first list element and the sum of a recursive step.

But this causes an infinite loop. Why?

The reason is because zipWith stops when either list is empty. And to decide if `b` is empty it needs to know if the tail of `b++[0]` is empty. But to find where the `[0]` begins it needs to know if `b` is empty, which is where we started.

There are ways to get around this issue in Haskell, see the [circular programming](docs/circular.md) section for more details.

In Atlas this isn't an issue however, because it assumes that vector operations will be non empty until proven otherwise. Essentially it finds the "greatest fixed point" if it exists whereas Haskell always returns the "least fixed point." So we can just write.

    a = 1,2,3,4
    b = b,0 tail+a
    ──────────────────────────────────
    10 9 7 4

Taking the head of this list is a truly lazy foldr.

## Minimal Basis of Turing Complete Ops

An impressive thing about the lambda calculus is that just lambda or even just the S and K combinators are sufficient to be Turing complete. How simple could Atlas be?

Folds are extremely powerful (see [expressiveness of fold](https://www.cs.nott.ac.uk/~pszgmh/fold.pdf)). My take is that we can think of any computation as repeatedly generating a new state based solely on a previous state. I guess this is more of an `iterate` in Haskell terms. But iterate is just a fold on an infinite list where you don't use the arg.

Since we have seen how to foldr, we can use it to get the nth state or last state. Just foldr, taking the first element where index=n. This would need something that resembles an if statement.

To create an if statement of the form `if a then b else c`, we could treat a non-empty list as true and an empty list as false. Then if we replace all elements of the list `a` with the value `b`, and finally append `c` then just taking the first element of the result would accomplish the task, because if `a` was false (empty) then the value would be `c` but if `a` was true (non empty), it would be the first element which has been replaced with `b`.

We have ops for append and head but what about replace? That can be done by doing a vectorized no op. One way to do that is to append two elements and take the head, thus ignoring the second value.

    a=()
    b="a is true"
    c="a is false"
    b;.,(a.)%,c head
    a=();
    b;.,(a.)%,c head
    ──────────────────────────────────
    a is false
    a is true

This code uses `;` (`single`) which just creates a list of one element. It also uses `()` which creates a list of zero elements of unknown (any) type.

Lambda calculus uses Church Numerals to represent numbers. We can just use lists to represent numbers, where the length of the list is the number. So we don't need actual numbers. But what are our lists lists of then? `()` creates a list of unknown type which would suffice. But that's kind of a special case that `()` means that, so how could we create atoms without it? Circular programs to the rescue again.

    a=a
    ──────────────────────────────────
    1:3 (a) cannot use value of the unknown type (TypeError)

It is an error to access the value of `a`, but we can create lists of them and not access them.

    a=a
    a;,a,a len
    ──────────────────────────────────
    3

`,` is the same as appending a single value, so it can be made with `_` and `;`.

So we need the following ops `.` `%` `=` `;` `head` `tail` `_`.

And all of these are very trivial (O(1)) ops except for `_`. But Atlas could have been made where lists are created symmetrically using a tree structure rather than a cons structure, in which case this would make that operation trivial as well, although then head and tail would be more complicated.

`_` and `;` could be combined into one op. If you wanted `;` just apply the combined op with an empty list, and if you wanted `_` just take the head of the result. This brings us down to 6 ops.

I could argue that `%` and `.` aren't really ops. They are indeed actually just no-ops that alter the return type. It might be possible to rely on auto vectorization/unvectorization to do away with them visually even though the generated intermediate representation would still be the same. FYI the whole concept of vector types isn't needed, and instead we could just provide a vectorized version of each op that we wish to use. Or maybe we don't need the unvectorized versions of the ops and could have only the vectorized versions?

`=` also isn't really an op, it actually just connects things in the intermediate representation which is just a graph of ops and their arguments, it's requirement is purely an artifact of having to write our code (which is ultimately a graph) as 1d text. And if we are going to go that far, we might as well combine head and tail into one op called `uncons` which returns two things. If we are speaking graph-wise then that would be no problem. So Atlas only needs 2 ops (`uncons` and `appendSingle`) and they are both simple? Debatable.

Regardless of how many ops you consider the minimal basis to be it is worth noting that in some ways it is simpler than the lambda calculus. The lambda calculus is untyped and would lose its Turing completeness if it were to be statically typed. However Atlas is easily statically typed, in fact you may not have realized it because you never need to specify type but the implementation actually is statically typed! Also lambdas are more difficult to implement lazily than values and have a lot going on behind the scenes with substitutions. Atlas' graph intermediate representation is definitely simpler than the lambda calculus'.

Lambda is of course very useful and beautiful, but I find it a nice result we don't even need it, so long as we have access to vectorized versions of head, tail, append, and single.

## Complex State

I've mentioned how you can think of any computation as a sequence of states and therefore accomplish it with circular programming. But said states are surely complicated right? And here we have only been using lists of scalars, there aren't even tuples or ways of constructing new types in Atlas. We don't need them though. If you want a list of tuples, just use two lists. Anytime you need to do an operation involving both values of the tuple, just use your operation on the two lists (each vectorized) and they will zipWith. If you have a tuple of size 3 and want to do an operation that needs all 3, it would actually be two operations (assuming it is a binary op), and so you would just be doing two separate zipped operations on 3 lists.

This way of handling complex state isn't as contrived as it sounds. For example Haskell has functions like mapAccumL, unfoldr, iterate, and scanl which can get tedious to use if you need to use tuples in your state - typically people switch to using monads in these cases. But these functions are really a single concept that is more elegantly expressed with a circular program.

For example consider our original Fibonacci numbers program, with iterate that would have been:

    map fst $ iterate (\(a,b)->(b,a+b)) (1,1)

Compared to Atlas

    a=1_1_(a tail+a)
    ──────────────────────────────────
    1 1 2 3 5 8 13 ...

And that's still a pretty simple case, you can combine any number of values in any way. The larger the tuples, the more elegantly circular programming will express the computation - albeit it may be harder to reason about to the untrained eye (or possibly all eyes?).


*the rest of this intro is an unfinished state*

-----------------------------------------


TODO more complex example but more readable than my bf interpreter

Just in case there was any doubt that the language is Turing Complete, I'll use these principles to implement a brianfuck interpreter:

'\0+("++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.------.--------.>+.>.":v2](0‿(0,‿(v5[(0‿(v1=='> then v6+1 else (v1=='< then v6-1 else v6)):v6)!@(v1=='+ then v4+1 else (v1=='- then v4-1 else v4)!;!@(v5](v6+1)))):v5]v6![:v4 then 0 else 1*(v1=='[!#) then v3+(1+(0‿(v2=='[ then v8+1 else (v2=='] then v8-1 else v8)):v8]v3![:v7!,!!==(v8](v3+1)) then 0‿(v9+(1,)):v9!;, else ($,,)!_![)) else (v4!&(v1==']) then v7-1!,!!==(v8[v3) then v9!;, else ($,,)!_!] else (v3+1))):v3)![:v1=='. then v4!; else ($,)_)


    source="++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.------.--------.>+.>."
    bracket_depth = 0 !if source == '[ then bracket_depth+1 else !if source == '] then bracket_depth-1 else bracket_depth
    not_truthy = !if value then 0 else 1
    wholes=0 wholes+,1
    code_pointer = 0 !if not_truthy * !len instruction == '[ then find_rbracket else !if value !& instruction == '] then find_lbracket else code_pointer+1
    instruction = !head code_pointer drop source
    pointer = 0 !if instruction == '> then pointer+1 else !if instruction == '< then pointer-1 else pointer
    state = (,0) (pointer take state) !@ (!;new_value) !@ (pointer+1) drop state

    value = !head pointer drop state
    new_value = !if instruction == '+ then value+1 else !if instruction == '- then value-1 else value

    current_bracket_depth = !head code_pointer drop bracket_depth

    // first point where bracket_depth = bracket_depth again
    find_rbracket = code_pointer + 1 + !head !concat !!if (!,current_bracket_depth) !!== (code_pointer+1) drop bracket_depth then ,!;wholes else ,,$

    // last point where bracket_depth = bracket_depth again
    find_lbracket = !last !concat !!if (!,current_bracket_depth-1) !!== code_pointer take bracket_depth then ,!;wholes else ,,$

    output = !if instruction == '. then !;value else ,$

    // todo terminate when code_pointer > source size
    '\0+concat output

    ---------------------------
    Hello World!

    6:15 (!head) head on empty list (DynamicError)

TODO update this code to the new left to right syntax

It can automatically be minified to:

    s="++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.------.--------.>+.>."
    '\0+_((a=![((b=0:(((c=![((d=0:(a='>)!?d+1)(a='<)!?d-1)d)}e=(,0):(d{e)!@(!;((a='+)!?c+1)(a='-)!?c-1)c))!@(d+1)}e))!?0)1)*a='[)!?b+1+![!_((!,(f=![(b}g=0:((s)='[)!?g+1)(s='])!?g-1)g)))!!=(b+1)}g)!!?,!;h=0:h+,1),,$)((c!?1)0)*a='])!?!]!_((!,(f-1))!!=b{g)!!?,!;h),,$)b+1)}s))='.)!?!;c),$

Note that you could use `I` for input rather than hard coding the input as `s=...`.

TODO regen minified given some new syntax changes.

That's a brainfuck interpreter (without input, but it could be supported similarly) in about 281 characters using only a handful of built in operations in a purely functional language. The brainfuck code might be more readable though... This could be done better, it is only my first attempt, and I'm new to writing complex problems in Atlas too! Some downsides to my method are that I treat lists like arrays and do random access using head of a drop, this is slow and verbose. Concepts like zippered lists could greatly improve it.


## Final thoughts on Circular Programming and Vectorization

Circular programming is a powerful technique, especially when your language has a nice syntax for vectorization. These techniques are often the simplest and best way to describe a sequence, but as I've shown you can take it too far. Moderation is key for real code. Still, going too far in play is enlightening, and hopefully you can have some fun playing with Atlas.

Let's end with two examples where circular programming is an elegant solution. The first "real world" problem is the Josephus Problem. Where 40 prisoners decide to go around in a circle, every third prisoner shooting themselves, until only 1 is left, which spot should you line up at to survive? The [haskell solution](https://rosettacode.org/wiki/Josephus_problem#Haskell) is 39 lines long without circular programming and [16 with](https://debasishg.blogspot.com/2009/02/learning-haskell-solving-josephus.html). There is a 1-line without circular programming but it is non obvious. Implementing it intuitively is simpler with circular programming.

In Atlas the solution is simple:

    nats=nats+1`1
    prisoners=nats take 40
    gunHolders = prisoners append (nats % 3. and (gunHolders.;)% concat)
    gunHolders tail.=gunHolders concat head
    ──────────────────────────────────
    28

The `!then gunHolders!; else $ concat` which is used twice may look scary but that's actually just a common pattern for doing a filter, not a fault of circular programming that Atlas lacks that operator for now. That last line is just selecting the first case it is the same person twice in a row. That catch op I alluded to earlier would be really handy here then we could just take the last before encountering an error.

I guess it is no surprise that a problem involving a circle has a nice circular programming solution. But calculating primes using the Sieve of Eratosthenesis is our next example. Typically the sieve is done on a fixed size, but if you use circular programming you can stream it.

There is a [functional pearl article](https://arxiv.org/pdf/1811.09840.pdf) about an even more efficient solution and it too uses circular programming.

TODO write alg from that article in Atlas

Now that I have some experience it would seem contrived to NOT use circular programming for solving these problems in any language.

# Future / Contributing

It could be worth porting Atlas to a more efficient language than Ruby, or maybe support compiling Atlas to C or Haskell for faster execution. It would be trivial to compile to Haskell except for the greatest fixed point capabilities to avoid infinite loops - I'm not sure how you would do that in Haskell.

It could be worth creating a binary version of the language where each instruction is 5 bits for a 38% code size reduction - which would be easy since Atlas uses only the 32 symbols (variables and numbers can be fit in too since Atlas doesn't actually use all symbols for both binary and unary operations yet). However it is a little silly to compete between different languages and it probably wouldn't be shorter than [Nibbles](http://www.golfscript.com/nibbles/) for most programs since it is far simpler.

Bug reports, design thoughts, op ideas, painpoints, feedback, etc. would be greatly appreciated. Please raise an issue or email me with your thoughts. `<name of this lang> at golfscript.com`.

There is also a google group for discussing the ongoing design of the language: [atlas-lang](https://groups.google.com/g/atlas-lang). Please ask to join with a message (this is just to prevent spam, all are welcome).

BTW there was a working Befunge-like 2D mode where you draw your program's graph rather than use variable names and parenthesis - it was smart about deducing connections so was probably even more concise. It was very interesting, but I removed it for now to focus on teaching circular programming rather than exploring a wacky idea (check out the very first commit of this language for a working prototype if you are curious).
