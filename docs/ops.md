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