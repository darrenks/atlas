# todo auto generate

for now this is just what you get when you type `ops` into the repl (organized slightly).

    LIST OPS #####################
    head [
    [a] → a
    "abc"[ → 'a

    last ]
    [a] → a
    "abc"] → 'c

    tail >
    [a] → [a]
    "abc"> → "bc"

    init <
    [a] → [a]
    "abc"< → "ab"

    len #
    [a] → Int
    "asdf"# → 4

    single ;
    a → [a]
    2; → [2]

    take [
    [a] Int → [a]
    "abcd"[3 → "abc"

    drop ]
    [a] Int → [a]
    "abcd"]3 → "d"

    count =
    [a] → [Int]
    "abcaab" count → [0,0,0,1,2,1]

    filter ?
    [a] [b] → [a]
    "abcd" ? (0,1,1,0) → "bc"

    sort !
    [a] → [a]
    "atlas" ! → "aalst"

    sortBy !
    [a] [b] → [a]
    "abc" ! (3,1,2) → "bca"

    chunkWhile ~
    chunk while second arg is truthy, resulting groups are of the form [truthy, falsey]
    [a] [b] → [[[a]]]
    "abcd" ~ "11 1" → [["ab","c"],["d",""]]

    concat _
    [[a]] → [a]
    "abc","123"_ → "abc123"

    append _
    [a] [a] -> [a] (coerces)
    "abc"_"123" → "abc123"

    cons `
    [a] a -> a (coerces)
    "abc"`'d → "dabc"

    snoc ,
    rear cons, promote of first arg is allowed for easy list construction
    [a] a -> a (coerces)
    1,2,3 → [1,2,3]

    transpose \
    [[a]] → [[a]]
    "abc","123"\ → ["a1","b2","c3"]

    reverse /
    [a] → [a]
    "abc" reverse → "cba"



    MATH OPS #####################
    add +
    Int Int → Int
    Int Char → Char
    Char Int → Char
    1+2 → 3

    sub -
    Int Int → Int
    Char Int → Char
    Char Char → Int
    5-3 → 2

    mult *
    Int Int → Int
    2*3 → 6

    pow ^
    Int Int → Int
    2^3 → 8

    div /
    Int Int → Int
    7/3 → 2

    mod %
    Int Int → Int
    7%3 → 1

    neg -
    Int → Int
    2- → -2

    abs |
    Int → Int
    2-,3| → <2,3>

    STRING OPS #####################
    join *
    [Str] Str → Str
    [Int] Str → Str
    "hi","yo"*" " → "hi yo"

    split /
    Str Str → [Str]
    "hi, yo"/", " → ["hi","yo"]

    replicate ^
    Str Int → Str
    "ab"^3 → "ababab"

    LOGICAL OPS #####################
    not ~
    a → Int
    2,0.~ → <0,1>

    eq =
    a a → [a]
    3=3 → [3]

    lessThan <
    a a → [a]
    4<5 → [5]

    greaterThan >
    a a → [a]
    5>4 → [4]

    and &
    a b → b
    1&2,(0&2) → [2,0]

    or |
    a a -> a (coerces)
    1|2,(0|2) → [1,2]

    IO OPS #####################
    read &
    Str → [Int]
    "1 2 -3"& → [1,2,-3]

    input $
    all lines of stdin
     → [Str]

    str `
    Int → Str
    12` → "12"

    DEBUG #####################
    show p
    a → Str
    12p → "12"
    no_zip=true

    type
    a → Str
    1 type → "Int"
    no_zip=true

    version
     → Str

    reductions
    operation count so far
     → Int


    VECTOR #####################
    repeat ,
    a → <a>
    2, → <2,2,2,2,2...

    range :
    Int Int → <Int>
    Char Char → <Char>
    3:7 → <3,4,5,6>

    from :
    Int → <Int>
    Char → <Char>
    3: → <3,4,5,6,7,8...

    unvec %
    <a> → [a]
    1,2+3% → [4,5]

    vectorize .
    [a] → <a>
    1,2,3. → <1,2,3>

    META #####################
    let @
    save to a variable without consuming it
    a a → [a]
    5@a+a → 10

    push {
    duplicate arg onto a lexical stack
    a → a
    5{,1,},2 → [5,1,5,2]

    pop }
    pop last push arg from a lexical stack
     → a
    5{,1,},2 → [5,1,5,2]

    flip \
    reverse order of previous op's args
    (a→b→c) → (b→a→c)
    2-\5 → 3

    apply @
    increase precedence, apply next op before previous op
    (a→b→c) → (a→b→c)
    (a→b) → (a→b)
    2*3@+4 → 14

