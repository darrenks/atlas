# Ops

TODO automatically generate this as it is likely to become out of date.

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
|    | if| `a b b -> b`|
|`,` | rep| `a -> [a]`|
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
|`&` | const| `a b -> a`|
|`\|` | pad| `[a] a -> [a]`|
|`?` | if| `a b b -> b` |
**Op modifier**
|`!` | vectorize |
**Atoms**
|`$` | nil| `Nil`|
|`"` | string| `Str`|
|`'` | char| `Char`|
|`[0-9]` |  int| `Int`|
**IO**
|`I` | input |`Str`|


In the op chart there is `Num`. All numeric operations can operate on `Int` or `Char` if it "makes sense". BQN does a good job describing this see [note on affine characters](https://mlochbaum.github.io/BQN/doc/types.html#characters).

Note structure for using `?` / `if` is:

    if cond then true_clause else false_clause

Which is the same as:

    false_clause ? cond ) true_clause

The symbol version is highly unusual compared normal languages, this order is least likely to require parenthesis. I expect it to only be used when code golfing, and that the more intuitive if/then/else style to be much easier to use. Despite the seemingly complicated structure this op is a normal function, what is unusual about it is that it is the only op that takes more than 2 args, and thus it does require some special syntax.