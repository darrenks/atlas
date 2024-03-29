# Examples

## FizzBuzz

The intro gives a somewhat short implementation of FizzBuzz with no explanation, here is that explanation. This is a fairly simple problem that doesn't even require any circular programing, it is a good example for learning vectors and other tricks however.

First we generate the numbers 1 to 100 then we want to mod each of those by 3 and 5. We need to repeat each number so that it mods by 3 and 5, if we didn't then it would only mod 1 by 3 and 2 by 5. Since both lists are 1d.

    let r=1:101
    r,%(3,5)
    ──────────────────────────────────
    1 1
    2 2
    0 3
    1 4
    2 0
    0 1
    ...

Now we can just take the `not` of each value to check if it was divisible or not

    let r=1:101
    r,%(3,5)~
    ──────────────────────────────────
    0 0
    0 0
    1 0
    0 0
    0 1
    1 0
    ...

Now we want to replicate the strings Fizz and Buzz that many times respectively. Here I have pretty printed it so that we can see the empty strings better.

    let r=1:101
    r,%(3,5)~^("Fizz","Buzz") p
    ──────────────────────────────────
    <<"","">,<"","">,<"Fizz","">,<"","">,<"","Buzz">,<"Fizz","">,<"","">...

No we just need to concatenate each sublist, and if empty use the number instead. There is an op for concatenating, and the latter can be done via an `or` op (which you can see from its type signature in the quickref will coerce the different types).

    let r=1:101
    r,%(3,5)~^("Fizz","Buzz")_|r
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

Now to golf it.

-   The parens can be removed by adding a `@` before the op to increase its precedence.
-   `101` can be replaced by `CI` the roman numeral
-   The `r` is only used twice, so we can save it to next available var with `{` and get it with `a`
-   The quotes around `"Fizz"` and `"Buzz"` can be removed since unset identifiers default to their string value.
-   The `,` can be removed in `3@,5` since it is implicit. It can't between Fizz and Buzz because it would think we want to assign to the identifier Buzz.

And we get:

    1:CI{,%3@5~^Fizz@,Buzz_|a
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

## Brainfuck

A brainfuck interpreter seems like it would be very difficult to create in Atlas because it is the epitome of imperative and Atlas has no ability to do anything imperatively. None-the-less it can be done by using the techniques described in [the circular doc](circular.md) to simulate state over time.

We will just worry about calculating the next state from the current state and let circular programming do the rest for us.

-   `+` `-` are simple, we just add or subtract from the previous state.
-   `<` `>` can not be directly implemented because Atlas does not have random access, but we can use a technique called zippered lists. We maintain the values right of the pointer in one list and the values to the left of the pointer in reverse order in another list. Now moving left and right can be accomplished by pushing and popping from the front of these lists.
-   `,` input, we will skip implementing this - it would not be difficult.
-   `.` output can be accomplished by returning a single output character or empty list at each step, the final output is just the concatenation of this.
-   `[` `]` are the trickiest to deal with, there are a couple strategies. When we encounter a `[` and the value is falsey we will search for the next matching `]` by treating brackets as 1 and -1 and finding when the cumulative sum = 0 again. When we encounter a `]` we will always pop from a stack that records where `[` were.

It might be more concise or simpler conceptually to simulate random access using `drop` than using zippered lists but such an operation would be asymptotically slower.

Note that you could use `$` for input rather than hard coding the input as `s=...`.

Here is the code to calculate the next state (variables with `2` in the name) from the previous:

    let s="+[[-]]."

    -- initial state
    let c=s
    let ml=()   -- memory to left of pointer (reversed)
    let mr=0,%  -- memory to the right of pointer
    let m=0     -- value at pointer
    let b=()    -- stack of code at ['s that we have entered

    -- character matches (for use in filters to simulate case statements below)
    let z=c[,.="><+-]["
    let r=z%/.  -- reverse order of z

    -- next state
    let b2=r~(m&(c,S;_b);,b@>)[|b catch,b[
    let next=(`0+('\-c{|<2&a))?[#]\c  -- the next code after matching ]
    let c2=r~(m~&next;,b@[)[|c catch,c[ >
    let m2= z~(mr[;,ml@[,m@+1,m@-1),m [
    let ml2=z~(m,ml,ml@>)         , ml[
    let mr2=z~(mr>,m@,mr)         , mr[

    -- show result
    "code"
    c2
    "memory"
    ml2/_m2_mr2[40*" "
    ml2#^"  "_"^"
    "b"
    b2 p
    ──────────────────────────────────
    code
    [[-]].
    memory
    1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
    ^
    b
    []

This code can be tested by changing `s` and the initial state to see if it behaves correctly generating the next state. Once that is confirmed, we just need to set it up so that each state value is a circular vector based on its next state and initial value.

    let s="++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++."
    let c=c2%`s.
    let ml=ml2^
    let mr=mr2%`(0,%).
    let m=m2^
    let b=b2^

    let z=c[,="><+-]["
    let r=z%/.
    let b2=r~(m&b@`c@`S;,b@>)@f[|b catch,b[
    let next=(`0+('\-c{|<2&a))?[#]\c
    let c2=r~(m~&next,b@[)[|c catch,c[ >
    let m2= z~(mr[;,ml@[,m@+1,m@-1),m [
    let ml2=z~(ml`m,ml@>)         , ml[
    let mr2=z~(mr>,mr@`m)         , mr[
    c[='.~(c?m[)+'\0
    ──────────────────────────────────
    Hello World!

The last line collect the output, chunk it while the code that remains is not empty, concat possible outputs, and turn them from numbers into characters.

### Golfed

A bit of golfing gets it down to 163 characters, likely less readable than brainfuck itself. (Note actually this is longer for now since behavior of `|` has changed and catch is manually needed, but surely could be golfed out, also saves can be used instead of sets).

    let s="++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++."
    >,r@`m~\z,r[%`0,@%.@r)[;,(l`m,l@>~\z,l[^@l[),m@+1,m@-1~\z,m[^@m~&((`0+('\-c{|<2&a))?[#]\c),(c[,.="><+-]["@z%/.@d~(m&b@`c@`S;,b@>)[|b catch,b[^@b[)~\d[|c catch,c[>%`s.@c[='.~(c?m[+'\0
    ──────────────────────────────────
    Hello World!

I've written way shorter in Ruby, but Ruby is an imperative language and you can use reflection to just convert Brainfuck into Ruby. Atlas can't do either of those things and none of Atlas' more powerful primitives are of any use either here, it is the worst case scenario. But at least it is possible...