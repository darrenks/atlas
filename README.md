# Atlas

Atlas is an [esolang](https://esolangs.org/) where you only have values and operations, like a simple calculator. However unlike a calculator, values can be lists which are lazy and operations can be vectorized over elements. It would still seem that you can't do much, except for a functional programming technique called circular programming. Not only does this make the language Turing complete, but actually quite concise, albeit confusing.

There are two choices for syntax. Both generate the same internal graph representation of your program before being evaluated.

-  1d mode uses prefix notation such as `* +1 2 3` which outputs `9`
-  2d mode has you literally draw the graph using arrows, although it is very good at deducing connections between adjacent characters without them.

        1
        v
        +<2
        v
        *<3

could have just been written

    1
    +2
    *3

The 2d mode is designed for fun, if you are interested in just the [theory](docs/theory.md), stick to the 1d version. Everything can be built from just `cons`, `head`, `tail`, `if`, `last` and vectorize without crazy schemes like other Turing Tarpits. I find this remarkable because those are simple operations and we are working with just values here.

Here is a more complex example, this program computes the infinite list of fibonacci numbers (using only a linear number of additions).

     1
     v
     >>:<+<<
       v ^ ^
     1 .>^ ^
     v v   ^
     >>:   ^
       v   ^
       .>>>^
       v

This is the graph representation

     1
     ╰→ : ← + ←╮
        │   │  │
        ├───╯  │
     1  │      │
     ╰→ :      │
        │      │
        ├──────╯
        │

This is the 1d representation

    fibs = : 1 x
    x = : 1 + fibs x

This is equivalent to the Haskell code:

    fibs = 1 : x where x = 1 : zipWith (+) fibs x

Even this might not make sense to you (it didn't to me at first), check out the section on [circular programming](docs/circular.md).

FYI The 2d version could have been rewritten more succinctly as just:

    1 1
    :.:
    .+^

To run your code download the source and

    ruby atlas.rb filename

(use file extension `.a1d` or `.a2d`)

I have tested with ruby 2.7.2 and 3.0.0

# Ops

| sym | alias | type |
| --- | --- | --- |
|`:` | cons | `a [a] -> [a]`|
|`@` | append| `[a] [a] -> [a]`|
|`[` | head| `[a] -> a`|
|`)` | tail| `[a] -> [a]`|
|`]` | last| `[a] -> a`|
|`(` | init| `[a] -> [a]`|
|`{` | take| `Int [a] -> [a]`|
|`}` | drop| `Int [a] -> [a]`|
|`?` | if| `a b b -> b`|
|`,` | repeat| `a -> [a]`|
|`;` | single| `a -> [a]`|
|`_` | concat| `[[a]] -> [a]`|
|`\` | transpose| `[[a]] -> [[a]]`|
|`=` | eq| `a a -> Int`|
|`~` | read| `Str -> Int`|
|`` ` `` | show| `a -> Str`|
|`+` | add| `Num Num -> Num`|
|`*` | mult| `Num Num -> Num`|
|`-` | sub| `Num Num -> Num`|
|`/` | div| `Num Num -> Num`|
|`%` | mod| `Num Num -> Num`|
|`~` | neg| `Num -> Num`|
**Op modifier**
|`!` | vectorize |
**Atoms**
|`$` | nil| `[a]`|
|`"` | string| `Str`|
|`'` | char| `Char`|
|`[0-9]` |  int| `Int`|
**2d manipulators**
|`^` | up |
|`v` | down |
|`>` | right|
|`<` | left|
|`#` | cross|
|`.` | dup|
**Explicit IO**
|`I` | input |`Str`|
|`O` | output |`a -> ()`|

# Types

There are 3 types in Atlas.
-   Integers (arbitrary precision).
-   Chars which are just integers that may have a different set of operations allowed on them including how they are displayed. Construct them using a single leading `'`.
-   Lists, which may also be of other lists. Construct them by creating an empty list with `$` or `!"` and then add things to them with cons (`:`) (or create a single element list more concisely with just `;`).

Strings are just lists of characters.

-   `123` this is an integer
-   `'x` this is char of the letter x
-   `"abc"` this is a string
-   `:1:2;3` this is the list [1,2,3] (1d syntax)

Some escapes are possible in chars/strings:

`\0` `\n` `\"` `\\` `\x[0-9a-f][0-9a-f]`

You may also use any unicode character the Atlas files are assumed to be UTF-8 encoded.

Integers are truthy if >0, chars if non whitespace, lists if non empty. This is only used by the if/else operator.

Atlas is statically typed. Currently inference works in a top down fashion, so you cannot infer the type of an empty list after the fact, which is why when creating empty lists, you must create one of the correct type using `$` for Integers and `"` for chars, using `!` to increase their rank as needed (e.g. use `!"` to create an empty list of type `[Str]` and `!!!$` to create an empty list of type `[[[[Int]]]]`).

# Vectorization

Automatic vectorization is the implicit zipping of operations when the ranks of arguments are too large. This is quite useful, one of the reasons APL code is so short.

For example `+` operates on scalars (rank 0). If we give it two lists (each rank 1), it will automatically perform a zip.

    + :1:2;3$ :2:4;6

    [3,6,9]

Longer lists are truncated to that of the smaller (this isn't the case for all vectorized languages, but useful in Atlas since we frequently use infinite lists).

    + :1;2 :2:4;6

    [3,6]

Arguments that would have too small of a rank after zipping are automatically replicated.

    + :1:2;3 1

first becomes

    [1,2,3] + [1,1,1,1,1...]

then results in

    [2,3,4]

Explicit vectorizations are allowed too. For example head (`[`) returns the first element of a list.

    [ :"hi" ;"there"

    "hi"

But we can explicitly vectorize this with `!` to instead return the head of each element. It could be used repeatedly with higher ranked lists.

    ![ :"hi" ;"there"

    "ht"

# 2d Syntax

This might be obvious, but let's make it explicit

-   Arrows connect to the character they point to (but incoming connections can come from any other direction).
-   `#` connects the character above it with the one below it and the one to the left with the one to the right. The direction of said connection is determined by context.
-   Two tokens can only have 1 direct connection between them (use arrows to build a second connection if that is really what you wanted).

Arg order is determined from the view of the output. For example

    1-2
     v

     1
     -2
     v

     ^
    2-1

are all `- 1 2` since from the output's perspective of `-` 1 is on the left and 2 on the right.

The implication is that mirroring your program will flip arg orders, but rotating it will always be ok (however you would need to take care of tokens > length 1 since those cannot be rotated).

! is considered part of the same token as the next character to the right.

Input and Output ops (`I` and `O`) can be omitted and inferred by context.

## How does this inferring by context work?

Atlas tries all possible options and errors if there isn't exactly 1 left, it even uses the type information to rule out impossible programs. In practice this means you don't really think about it, just draw your program, but occasionally there might be an ambiguous program that you need to guide it by doing something like adding some arrows.

# 1d Syntax

It is just prefix (Polish) notation. Think of it as C code function call syntax but without any of the parenthesis or commas.

You can put assignment statements on their own lines, or leave them in place. The fibs program could have been written as

    fibs = : 1 x
    x = : 1 + fibs x

or

    x = : 1 + fibs = : 1 x x

You may also use the name aliases instead of symbols (and you will have to for `=` since that is assignment now). So you could have written

    x = cons 1 add fibs = cons 1 x x

In the future we could add parenthesis or indenation to help make it more readable.

# Caveats

## Stack Overflow

Recursion is used within the lazylib and so you will hit a stack overflow if you work with big lists. On my computer this becomes a problem around size 1000. I'd definitely like to address this issue, but it should work fine for toy problems for now.

## Num

In the op chart there is `Num`. All numeric operations can operate on `Int` or `Char` if it "makes sense". BQN does a good job describing this see [note on affine characters](https://mlochbaum.github.io/BQN/doc/types.html#characters). One difference is that in Atlas `mod` can be done on a `Char` if the denominator is an `Int`.

## No auto replication for append and cons

Due to the type inference algorithm, `@` append and `:` cons can't auto replicate their arguments. This is because we need to know the return type of the operation without consulting the type of the 2nd arg yet since it could be part of a circular program. In practice this doesn't matter much since you can manually replicate with `,`.


## Some special vectorizations

-   `!~` (read) will take a Str and return `[Int]`, splitting on whitespace.
-   `!I` (input) will return `[Str]` splitting on newlines.

The `!I` can be inferred if you omit input.

## Note on IO

Input is a regular string value, but thanks to laziness, interactive programs can still be written.

Output automatically converts any type to a string by joining with spaces and newlines if rank >= 2 otherwise. It is similar to [Nibbles](http://golfscript.com/nibbles).

# More

See more examples in the [cookbook](docs/cookbook.md)

# Future / Contributing

This is a prototype version of Atlas, I wasn't quite sure where it was going when I wrote it, so some of the code is quite hacky, although fully functional and decently well tested. I want to rewrite in something that compiles to Javascript so that it can be used from the web (and build a cool debugger) - that's one reason I wrote it in Ruby instead of Haskell which would have been easier, this way I know a port to JS won't be hard. The biggest issues in this version are around the parser and type inference. I think they could be combined and solved like a max flow problem which would be more elegant and theoretically faster. The current type inference is only downwards and so things like nil, read, etc aren't as nice as they could be - this isn't a big deal at all, but I would love to clean that code up and improve things a bit.

Many ops could be added, but I thought it would be best to start things off about as simple as Befunge. Also type overloading could be added in many places, but there are downsides to it because compact 2d programs will be more likely to be ambiguous.

I'd like help finding bugs and deciding if this is fun or not before continuing. Other thoughts are welcome and if you'd like to join in the effort let me know! Seriously, feedback is greatly appreciated. My email can be found on the golfscript website or raise an issue.
