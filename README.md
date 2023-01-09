# Atlas

Atlas is an [esolang](https://esolangs.org/) whose purpose is to teach and explore the functional programming technique known as circular programming and its synergy with vectorization.

Currently Atlas is in Alpha. It has all the essential features and works. But, I'd like to do more with it, see Future / Contributing below.

Atlas consists purely of operators applied to values (like a calculator) and assignment. There are no control structures, functions, blocks, lambdas, etc. The purpose of this simplicity is twofold: to force you to really use circular programming, and to make picking it up easy. Despite the simplicity, it is actually very concise because circular programming and vectorization are seriously powerful.

The techniques presented in the tutorial are applicable to other lazy languages like Haskell, they will just be more verbose (because zipWith isn't done implicitly or maybe require a helper function here and there). Even if you are not interested in Atlas or already know about circular programming, I hope this will be an interesting read, it presents how you can implement foldr with circular programming (something I have not seen anywhere else) and therefore create a very simple basis for a programming language.

The purpose of this README is to teach you about circular programming without you having to know anything about Atlas already. However it assumes some familiarity with laziness. Just note, there is no precedence in Atlas, code is evaluated right to left. If you want to get into the nitty gritty of Atlas specifically, check out the [docs folder](docs/), it has some cool features that are omitted in this README to keep it simple.

You can run code by downloading the Atlas source and saving your Atlas code to a file then running:

    ruby atlas.rb filename.atl

I have tested with ruby 2.7 and 3.1.

## Circular Programming Intro

Let's look at the first example I ever saw of circular programming. It was the Haskell program:

    a=1:1:zipWith (+) a (tail a)

Which generates the infinite list of fibonacci numbers. In Atlas this would be:

    a=1 1 a+tail a
    ──────────────────────────────────
    1 1 2 3 5 8 13 ...

The only real difference between Atlas and Haskell here is that the zipWith is implicit because Atlas is vectorized. The `:` is also implicitly added between multiple expressions.

The first time I saw this, I just dismissed it as some weird special case trick that I didn't understand and assumed it wasn't practical, but actually it isn't a trick and it is useful, it is probably the most efficient way to compute the Fibonacci numbers sequence in Haskell.

If we do not want an infinite list, we could just take the first n elements of the list and we can do so without an infinite loop, since we never ask for an infinite number of elements.

    a=1 1 a+tail a
    10 take a
    ──────────────────────────────────
    1 1 2 3 5 8 13 21 34 55

This syntax is different than Haskell's, in Atlas all functions are treated as operators, since `take` has two arguments it goes between its operands like other binary operators such as `+`.

How does it work? First remember that Atlas and Haskell are [lazy](https://en.wikipedia.org/wiki/Lazy_evaluation), so they don't do anything until we ask about the elements of `a`. Atlas starts asking for the elements of `a` in order so that it can print them. It is easy to see that the first 2 elements are 1 without needing to know the rest. The third element is the result of a `zipWith` and is computed only using the first two elements, which we already know. `zipWith` starts moving through these lists as they are generated creating an infinite list.

If this is explanation of fibonacci numbers is still confusing, here's another way of looking at it. It's like `a` is actually a recursive function that takes no arguments. Consider this definition of a function for `a` in Haskell.

    a() = 1:1:zipWith (+) (a()) (tail(a()))

It's still relying on laziness to treat the result like a stream, but there is no circular definition of values, only a recursive function definition.

It is also computes the fibonacci numbers. The base cases work and so does the inductive step so therefore it is correct. But it is exponentially slower, because it computes `a()` twice rather than using the same value. This could be fixed with an assignment:

    a() = let a2 = 1:1:a() in zipWith (+) a2 (tail a2)

But what is the point of making `a` a function, it doesn't use its argument? Functions without arguments **ARE** values in a pure language! Just define `a` as a value and we end up with the code we started with.

Laziness will not save the day from all circular programs, only so long as we do not ask for a value in a circle before it has been computed. If we had said `a = a+1` we would hit an infinite loop in Haskell when we ask for the value of `a`. What is `a`? It is `a+1`, and what is `a`? It is `a+1`, etc. Note that this would actually give a type error in Atlas but if you got around that it would raise an infinite loop error since it would also detect the circular dependency at runtime. Circular dependencies of values can always be detected at runtime but not all infinite loops can be since there are other ways to create them (that would break the halting problem).

Before we go deeper, I'd like to mention that circular programming seems to refer to two different types of things that are related. We will be exclusively talking about the kind you can do by zipping, but there is another type that involves using tuple return values seemingly before they are computed. It is worth knowing about, but not applicable in Atlas.
[Here is a tutorial](http://www.cs.umd.edu/class/spring2019/cmsc388F/assignments/circular-programming.html) on that.

### Scanl

Generating streams that depend on past values of a sequence is probably the most common use of circular programming, but what else can it do?

We can use it to calculate the scanl of a list and any operation! Suppose we had the list `1 2 3 4` and we wanted to calculate the prefix sums. Of it (e.g. `1 3 6 10`).

We can do that like this:

    a=1 2 3 4
    b=a+0 b
    ──────────────────────────────────
    1 3 6 10

And this works in Haskell too:

    a=[1,2,3,4]
    b=zipWith (+) a (0:b)

It works much the same way as the fibonacci sequence. The first element is the first element of `a` + 0, the second is the result of that + the next element in `a`.

And we can do a foldl simply be getting the last element of the scanl:

    a=1 2 3 4
    b=a+0 b
    last b
    ──────────────────────────────────
    10

BTW we can easily generate the list of natural numbers using this technique if we first define an infinite list of 1's and compute the prefix sums on them. The repeating list can be done via:

    ones=1 ones
    ──────────────────────────────────
    1 1 1 1 ...

There's also an op to make this more concise:

    ones=,1
    ──────────────────────────────────
    1 1 1 1 ...

So we could define the natural numbers as:

    nats=1 nats + ,1
    ──────────────────────────────────
    1 2 3 4 5 ...


## Transpose

How can we transpose a list defined as so?

    a=(1 2 3 4) (5 6 7 8)
    ──────────────────────────────────
    1 2 3 4
    5 6 7 8

The first row will be the heads of each row of `a`, which can be gotten with `!head`

    a=(1 2 3 4) (5 6 7 8)
    !head a
    ──────────────────────────────────
    1 5

Note the `!` which means apply this function one level down. Just `head` would have given the first row. You may have been expecting a column of 1 5 instead of a row, but the heads of each element is just a 1D list and so it displays as such.

The next row should be the heads of the tails:

    a=(1 2 3 4) (5 6 7 8)
    !head !tail a
    ──────────────────────────────────
    2 6

And the next row would be the head of the tail of the tails. So essentially to transpose we want the heads of the repeated tailings of a 2D list, which we can do with circular programming of course.

    a=(1 2 3 4) (5 6 7 8)
    tails= a (!!tail tails)
    ──────────────────────────────────
    1 2 3 4
    5 6 7 8

    2 3 4
    6 7 8

    3 4
    7 8

    4
    8





    2:11 (!!tail) tail on empty list (DynamicError)

It is worth mentioning that this output is a 3D list, which is really just a list of list of a list, there is nothing special about nested lists, they are just lists. The separators for output are different however which makes them display nicely. You can also use the `show` op to display things like Haskell's show function.

Also note the error. It would occur for the same program in Haskell too:

    tails=map (map tail) (a:tails)

Anytime we see something of the form `var = something : var` it is defining an infinite list. This list clearly can't be infinite though, hence the error. It can be avoided by taking elements of length equal to the first row.

    a=(1 2 3 4) (5 6 7 8)
    tails= a (!!tail tails)
    tails const head a
    ──────────────────────────────────
    1 2 3 4
    5 6 7 8

    2 3 4
    6 7 8

    3 4
    7 8

    4
    8

`const` is a simply a function that takes two args and returns the first. But since it is zippedWith, it has the effect shortening the first list if the ignored arg is shorter. `head a` is the length we want.

I have some ideas about creating an op to catch errors and truncate lists, but for now this manual step is required.

To get the transpose now we just need to take the heads of each list:

    a=(1 2 3 4) (5 6 7 8)
    tails= a (!!tail tails)
    !!head tails const head a
    ──────────────────────────────────
    1 5
    2 6
    3 7
    4 8

## Scan on 2D lists

We've seen how to do scanl on a list, but how does it work on 2D lists?

    a=(1 2 3 4) (5 6 7 8)
    b=(,0) a+b
    10 !take b
    ──────────────────────────────────
    0 0 0 0 0 0 0 0 0 0
    1 2 3 4
    6 8 10 12

The same way, we just have to start with a list of 0s instead of one. I did a `10 !take` purely for display purposes.

That was easy, but what if we wanted to do it on rows instead of columns without transposing twice?

We can do a zipped cons:


    a=(1 2 3 4) (5 6 7 8)
    b=(,0)! a+b
    ──────────────────────────────────
    0 1 3 6 10
    0 5 11 18 26

Note that we could have written that more succinctly as:

    a=(1 2 3 4) (5 6 7 8)
    b=0@a+b
    ──────────────────────────────────
    0 1 3 6 10
    0 5 11 18 26

Because it knows that the left arg of append needs to be a list given the type of `a+b` and so it automatically replicates it and zips once (`@` is used because implicit cons default to promoting rather than replicating). This may seem like magic, but it has fairly simple rules that dictate this behavior, see [docs/vectorization.md](Vectorization) if interested. Both of these representations generate the same code.

This doesn't work if we port it to Haskell! It infinitely loops:

    b=zipWith (:) (repeat 0) (zipWith(zipWith (+))a b)

The reason is because the first zipWith needs to know that both args are non empty for the result to be non empty. And when checking if the second arg is empty, that depends on if both `a` and `b` are non empty. But checking if `b` is non empty, is the very thing we were trying to decided in the first place since it is the result of the first zipWith. `b` is non empty if `a` and `b` are non empty. Haskell deals with this in the simplest way, but in this particular case it is definitely not the most useful way.

Essentially what we really want is the "greatest fixed point". In general the greatest fixed point isn't clearly defined or efficient to compute. In this case it is both though, and Atlas finds it. The way it works is if it finds that there is a self dependency on a zipWith result, it has "faith" the result will be non empty. Afterwards it checks that the result was in fact non empty, otherwise it throws an infinite loop error (which is what it would have done with out the faith attempt in the first place). I'd like to generalize this logic to work for finding any type of greatest fixed point, but it will be more difficult for other cases as it would require back tracking in some cases.

## Map and Nested Map

It's not obvious that we don't need map to map. But it is quite easy to eliminate the need: just use the list you wish to map over where you would use the map arg.

For example:

    let a = [1,2,3]
    in map (\i -> (i + 2) * 3) a

In Atlas is:

    a = 1 2 3
    (a+2)*3
    ──────────────────────────────────
    9 12 15

If you need to use the map arg multiple times, that is fine.

    let a = [1,2,3]
    in map (\i -> i * (i - 1) / 2)

In Atlas is:

    a = 1 2 3
    (a*(a-1))/2
    ──────────────────────────────────
    0 1 3

This same idea also replaces the need for any explicit zipWith of a complex function. A zipWith of a complex function is just a series zipWiths of a simple function. This is one reason why languages like APL are so concise, they never need map or zipWith and these are extremely common operations.

It is worth noting that if you are using an operation that could be applied at different depths (for example head of a 2D list), you will need to use `!`'s the proper number of times to apply them at the right depth. `*` never needs `!` since it can only be applied to scalars.

Ok, so that's great, but this doesn't work if we need to do nested maps, for example generating a multiplication table:

    map (\i -> map (\j -> i*j) [1,2,3]) [1,2,3]

Won't work directly:

    (1 2 3) * (1 2 3)
    ──────────────────────────────────
    1 4 9
The reason is because the `*` zips instead of doing a 'cartesian product'.

Doing a cartesian product is easy though. We just replicate each list in a different dimension

    3 take ,(1 2 3)
    " and "
    3 !take !,(1 2 3)
    ──────────────────────────────────
    1 2 3
    1 2 3
    1 2 3
     and
    1 1 1
    2 2 2
    3 3 3

`,` means repeat, but it could have been done using our circular technique for creating infinite lists. Also the `3 take` is not needed because each list will take the shorter of the two and they are replicated in different directions with the other dimension still being 3. So the final program can be:

    (,(1 2 3)) * !,(1 2 3)
    ──────────────────────────────────
    1 2 3
    2 4 6
    3 6 9

This technique can do any degree of nesting with any dimension lists. Essentially you need to think of each operation in a computation taking place at a location in nD space, where n is the number of nested loops. And despite the name you can use a cartesian product on any operation not just multiplication.

Note for code golfers, the left `,` isn't needed since it knows it needs a 2D list. We could have written

    (1 2 3)*!,1 2 3
    ──────────────────────────────────
    1 2 3
    2 4 6
    3 6 9

or even

    a*!,a=1 2 3
    ──────────────────────────────────
    1 2 3
    2 4 6
    3 6 9

## Foldr

Earlier we saw how we could do a scanl and thus a foldl, but there are reasons you would want to be able to do a scanr / foldr instead. For example, suppose you wanted to see if any elements in a list were falsey. That is essentially a fold on a logical AND. But with a foldl we can't lazily terminate, because a foldl is like getting the last element of a scanl, it requires looping through all elements to get there. However a foldr is like getting the first element of a scanr and thus will lazily terminate.

Another reason is scanr can actually be used to implement `last` whereas there is no way do this with scanl, it can allow us to reach a small basis of ops for a Turing complete language - more on that in the next section.

When first exploring the ideas of this language I didn't think it was possible to scanr or foldr, and I still thought this stuff was cool. I was really blown away when I discovered how to. It can actually be done in much the same way as scanl, but with a bit of extra care.

To sum via scanr we want the last element to be last element of the original list + 0, and the 2nd to last to be the sum of the last 2 numbers + 0 and so on. So in Haskell it seems we could just write:

    a = [1,2,3,4]
    b = zipWith (+) a (tail (b++[0]))

Another way to think of it is the first element is the sum of the first list element and the sum of a recursive step.

But this causes an infinite loop. Why?

The reason is because zipWith stops when either list is empty. And to decide if `b` is empty it needs to know if the tail of `b++[0]` is empty. But to find where the `[0]` begins it needs to know if `b` is empty, which is where we started.

One option around this is to define two different zipWiths, one that only checks if left is empty and a different version that only checks if the right is empty. So in this case we would need to use zipWithL which doesn't check if the right arg is empty, only the left. These zipWiths would throw an error if the opposite side was the shorter list (rather than truncate). This isn't ideal because it puts the burden on the user to choose the correct zipWith and it actually still doesn't work because `++` still needs to know when the left operand is empty, but it would work if Haskell constructed lists symmetrically with `++` as a primitive instead of cons.

There is a solution though! We can define a function that adds an infinite list to the end of a list and construct it in such a way that it doesn't need to check anything if asked if empty, since it can never be empty even after tailing it. This allows zip's empty check to immediately succeed. Here is that function in Haskell:

    pad :: [a] -> a -> [a]
    pad a v = h : pad t v
       where
          ~(h,t) =
             if null a
             then (v,[])
             else (head a,tail a)

This function pads a list by adding an infinite list of a repeating element after it (e.g. `pad [1,2,3,4] 0` is `[1,2,3,4,0,0,0,...]`. But critically it starts by returning a list rather than first checking which case to return.

Notice that it always returns `h : pad t v`, which is a non empty list, regardless of if `a` was empty or not, thus nothing needs to be computed when asked if the result is empty. It is only the contents of said list that depend on if `a` was empty. This is definitely not the most intuitive way to define this function, but it is the only way that is sufficiently lazy.

Now we can write:

    a = [1,2,3,4]
    b = zipWith (+) a (tail (pad b 0))

And it works! Atlas has a builtin for pad, it is `|` so we could just write:

    a = 1 2 3 4
    b = a + tail b|0
    ──────────────────────────────────
    10 9 7 4

## Minimal Basis of Turing Complete Ops

Folds are extremely powerful (see [expressiveness of fold](https://www.cs.nott.ac.uk/~pszgmh/fold.pdf)). My take is that we can think of any computation as repeatedly generating a new state based solely on a previous state. I guess this is more of an `iterate` in Haskell terms. But iterate is just a fold on an infinite list where you don't use the arg. The Transpose example above did an iterate with circular programming to repeatedly tail.

Since we have seen how to foldr, we can use it to get the nth state or last state. Just foldr, taking the first element where index=n. We do need an `if` statement to do that, which Atlas has, but `if` could have been done as follows. Let's call our condition `c` which is a True if non empty and False if empty. And we want `a` if True and `b` if False. We can then write:

    head ((a ()) const c) | b

It works by replacing `c` with `a` if non empty, appending `b` and then taking the first. If `c` was empty then the result is `b` otherwise it is `a`.

Example:

    head (("true" ()) const "") | "false"
    head (("true" ()) const "asdf") | "false"
    ──────────────────────────────────
    false
    true

`&` isn't necessary either, it can be done by just appending something and taking the head, care will be needed to convert to a matching type since lists must be homogeneous in Atlas.

Now it may seem a little silly that we were trying to define a built in for `last` and `if` and we ended up using a new builtin, pad (`|`), which is kinda similar to cons. But it is actually possible to do this without pad if Atlas was a little bit smarter about calculating greatest fixed points - which I have a plan to do soon and elaborate on. Then the whole language could be built from just a few builtins, something to append (as opposed to cons), something to put things inside a list (e.g. `1 -> [1]`), and head/tail.

That's four ops. It is possible to reduce this by combining append and single into 1 function. E.g. `"as" X "df"` appends and puts in a list, giving `["asdf"]`. If you wanted to just put one thing in a list, just append an empty list. If you wanted to just append, then just take the head. Empty list can be created by tailing a list of size 1, which is what our `X` function creates. No atoms need to be defined in the language, we could pass `X` a circular definition so long as we don't access the value. `tail a X a=a` would then be the empty list. The way Atlas' type system works this would have type Nil which can become any type.

Head/tail could be combined into a single function uncons, but then we need a way to support multiple assignment.

Numbers aren't needed, they could be represented as the length of a list or if you cared about efficiency a list of bits where each bit is an empty list or non empty. This is similar to strategies that are used for numbers in the lambda calculus.

This would give a Turing Complete basis that is only 2 ops, plus assignment and `!`. `!` isn't truly needed in that we could define ops that perform at predefined zip levels, I'm not sure how many we would need though (probably only a couple). This is very arguably simpler than the SK calculus because there are no partial applications and the language can be statically typed! I personally find it more intuitive to work with values and first class lists than partial functions.

## Complex State

I've mentioned how you can think of any computation as a sequence of states and therefore accomplish it with circular programming. But said states are surely complicated right? And here we have only been using lists of scalars, there aren't even tuples or ways of constructing new types in Atlas. We don't need them though. If you want a list of tuples, just use two lists. Anytime you need to do an operation involving both values of the tuple, just use your operation on the two lists and they will zipWith. If you have a tuple of size 3 and want to do an operation that needs all 3, it would actually be two operations (assuming it is a binary op), and so you would just be doing two zipped with operations on 3 lists. Technically Atlas does have a ternary operator (the if/else statement) and it would just be doing a zipWith3 if you happened to combine them all in a single operation.

This way of handling complex state isn't as contrived as it sounds. For example Haskell has functions like mapAccumL, unfoldr, iterate, and scanl which can get tedious to use if you need to use tuples in your state - typically people switch to using monads in these cases. But these functions are really a single concept that is more elegantly expressed with a circular program.

For example consider our original Fibonacci numbers program, with iterate that would have been:

    map fst $ iterate (\(a,b)->(b,a+b)) (1,1)

Compared to Atlas

    a=1 1 a+tail a
    ──────────────────────────────────
    1 1 2 3 5 8 13 ...

And that's still a pretty simple case, you can combine any number values in any way.

TODO more complex example but more readable than my bf interpreter

Just in case there was any doubt that the language is Turing Complete, I'll use these principles to implement a brianfuck interpreter:

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

    ──────────────────────────────────
    Hello World!

    6:15 (!head) head on empty list (DynamicError)

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

    nats=1 nats+1
    prisoners=40 take nats
    gun_holders = prisoners @ concat !if nats % 3 then !;gun_holders else $
    head concat !if gun_holders !== tail gun_holders then !;gun_holders else $
    ──────────────────────────────────
    28

The `concat !if ... !;gun_holders else $` which is used twice may look scary but that's actually just a common pattern for doing a filter, not a fault of circular programming that Atlas lacks that operator for now. That last line is just selecting the first case it is the same person twice in a row. That catch op I alluded to earlier would be really handy here then we could just take the last before encountering an error.

I guess it is no surprise that a problem involving a circle has a nice circular programming solution. But calculating primes using the Sieve of Eratosthenesis is our next example. Typically the sieve is done on a fixed size, but if you use circular programming you can stream it.

TODO clean this up

    _!if (1+v1=1(v2=2 1+v2)*v1)%v2 then $ else !;v2
    ──────────────────────────────────
    2 3 5 7 11 13 17 19 23 29 31 ...

There is a [functional pearl article](https://arxiv.org/pdf/1811.09840.pdf) about an even more efficient solution and it too uses circular programming.

Now that I have some experience it would seem contrived to NOT use circular programming for solving these problems in any language.

# Caveats

## Stack Overflow

Recursion is used to implement primitives and so you will hit a stack overflow if you work with big lists. On my computer this becomes a problem around size 1000. I'll be addressing this soon.

# Future / Contributing

I'd like to do add some more advanced features / ops to give it lasting appeal, see [todo](docs/todo.txt). I'd also like to port it to Nim or another static language that can also compile to javascript so that it can be used online easily. But first it would be very valuable to get feedback and ideas from **YOU**. I would love to collaborate with anyone who finds this interesting.

Please raise an issue or email me with your thoughts. `<name of this lang> at golfscript.com`.

There is also a google group for discussing the ongoing design of the language: [atlas-lang](https://groups.google.com/g/atlas-lang). Please ask to join with a message (this is just to prevent spam, all are welcome).

BTW there was a working Befunge-like 2D mode where you draw your program's graph rather than use variable names and parenthesis - it was smart about deducing connections so was probably even more concise. It was very interesting, but I removed it for now to focus on teaching circular programming rather than exploring a wacky idea (check out the first commit of this language for a working prototype if you are curious).
