# More Circular Programming

This doc is an unfinished state

## Transpose

How can we transpose a list defined as so?

    a=(1,2,3,4),(5,6,7,8)
    ──────────────────────────────────
    1 2 3 4
    5 6 7 8

The first row will be the heads of each row of `a`, which can be gotten with `.` and `head`

    a=(1,2,3,4),(5,6,7,8)
    a.head
    ──────────────────────────────────
    1 5

Note the `.` which takes one arg and vectorizes it. Just `head` would have given the first row. You may have been expecting a column of 1 5 instead of a row, but the heads of each element is just a 1D list and so it displays as such.

The next row should be the heads of the tails:

    a=(1,2,3,4),(5,6,7,8)
    a.tail head
    ──────────────────────────────────
    2 6

And the next row would be the head of the tail of the tails. So essentially to transpose we want the heads of the repeated tailings of a 2D list, which we can do with circular programming of course.

    a=(1,2,3,4),(5,6,7,8)
    tails=tails..tail%%`a
    ──────────────────────────────────
    1 2 3 4
    5 6 7 8

    2 3 4
    6 7 8

    3 4
    7 8

    4
    8




    2:14 (tail) tail on empty list (DynamicError)

Here the `..tail%%` means perform the tail operation two levels deep. See the Vectorization section for more info.

It is worth mentioning that this output is a 3D list, which is really just a list of list of a list, there is nothing special about nested lists, they are just lists. The separators for output are different however which makes them display nicely. You can also use the `show` op to display things like Haskell's show function.

Also note the error. It would occur for the same program in Haskell too:

    tails=map (map tail) (a:tails)

Anytime we see something of the form `var = something : var` it is defining an infinite list. This list clearly can't be infinite though, hence the error. It can be avoided by taking elements of length equal to the first row.

    a=(1,2,3,4),(5,6,7,8)
    tails=tails..tail%%`a
    tails take (a head len)
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

    a=(1,2,3,4),(5,6,7,8)
    tails=tails..tail%%`a
    tails take (a head len)..head
    ──────────────────────────────────
    1 5
    2 6
    3 7
    4 8

## Scan on 2D lists

We've seen how to do scanl on a list, but how does it work on 2D lists?

    a=(1,2,3,4),(5,6,7,8)
    b=a+b%%`(0,%)
    b. take 10
    ──────────────────────────────────
    0 0 0 0 0 0 0 0 0 0
    1 2 3 4
    6 8 10 12

The same way, we just have to start with a list of 0s instead of one and unvectorize the cons. I did a `10 take` purely for display purposes.

That was easy, but what if we wanted to do it on rows instead of columns without transposing twice?

We can do a zipped append:

    a=(1,2,3,4),(5,6,7,8)
    b=a+b`0
    ──────────────────────────────────
    0 1 3 6 10
    0 5 11 18 26

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

    a = 1,2,3
    a+2*3
    ──────────────────────────────────
    9 12 15

If you need to use the map arg multiple times, that is fine.

    let a = [1,2,3]
    in map (\i -> i * (i - 1) / 2)

In Atlas is:

    a = 1,2,3
    a*(a-1)/2
    ──────────────────────────────────
    0 1 3

This same idea also replaces the need for any explicit zipWith of a complex function. A zipWith of a complex function is just a series zipWiths of a simple function. This is one reason why languages like APL are so concise, they never need map or zipWith and these are extremely common operations.

It is worth noting that if you are using an operation that could be applied at different depths (for example head of a 2D list), you will need to use `!`'s the proper number of times to apply them at the right depth. `*` never needs `!` since it can only be applied to scalars.

Ok, so that's great, but this doesn't work if we need to do nested maps, for example generating a multiplication table:

    map (\i -> map (\j -> i*j) [1,2,3]) [1,2,3]

Won't work directly:

    (1,2,3) * (1,2,3)
    ──────────────────────────────────
    1 4 9
The reason is because vectorization zips instead of doing a 'cartesian product'.

Doing a cartesian product is easy though. We just replicate each list in a different dimension

    1,2,3,% take 3
    " and "
    1,2,3., take 3
    ──────────────────────────────────
    1 2 3
    1 2 3
    1 2 3
     and
    1 1 1
    2 2 2
    3 3 3

`,` means repeat, but it could have been done using our circular technique for creating infinite lists. Also the `3 take` is not needed because each list will take the shorter of the two and they are replicated in different directions with the other dimension still being 3. So the final program can be:

    1,2,3, * (1,2,3.,)
    ──────────────────────────────────
    1 2 3
    2 4 6
    3 6 9

This technique can do any degree of nesting with any dimension lists. Essentially you need to think of each operation in a computation taking place at a location in nD space, where n is the number of nested loops. And despite the name you can use a cartesian product on any operation not just multiplication.

Note for code golfers, the left `,` isn't needed since it knows it needs a 2D list. We could have written

    1,2,3*(1,2,3.,)
    ──────────────────────────────────
    1 2 3
    2 4 6
    3 6 9

or even shorter by pushing and popping the 1,2,3

    1,2,3{.,*}
    ──────────────────────────────────
    1 2 3
    2 4 6
    3 6 9



## Foldr continued

One option around this is to define two different zipWiths, one that only checks if left is empty and a different version that only checks if the right is empty. So in this case we would need to use zipWithL which doesn't check if the right arg is empty, only the left. These zipWiths would throw an error if the opposite side was the shorter list (rather than truncate). This isn't ideal because it puts the burden on the user to choose the correct zipWith and it actually still doesn't work because `++` still needs to know when the left operand is empty, but it would work if Haskell constructed lists symmetrically with `++` as a primitive instead of cons.

There is a solution though! We can define a function that adds an infinite list to the end of a list and construct it in such a way that it doesn't need to check anything if asked if empty, since it can never be empty even after tailing it. This allows zip's empty check to immediately succeed. Here is that function in Haskell:

    pad :: [a] -> a -> [a]
    pad a v = h : pad t v
       where
          ~(h,t) =
             if null a
             then (v,[])
             else (head a,tail a)

TODO update this with 1 arg version

This function pads a list by adding an infinite list of a repeating element after it (e.g. `pad [1,2,3,4] 0` is `[1,2,3,4,0,0,0,...]`. But critically it starts by returning a list rather than first checking which case to return.

Notice that it always returns `h : pad t v`, which is a non empty list, regardless of if `a` was empty or not, thus nothing needs to be computed when asked if the result is empty. It is only the contents of said list that depend on if `a` was empty. This is definitely not the most intuitive way to define this function, but it is the only way that is sufficiently lazy.

Now we can write:

    a = [1,2,3,4]
    b = zipWith (+) a (tail (pad b 0))

And it works!
