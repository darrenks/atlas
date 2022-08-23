# Cookbook

Most of this is TODO or old for now

### Integer Comparisons
Since integers are defined as truthy if >0, we can just use subtraction and if/else (`?`) to achieve the desired effect.

### Char conversion to/from Ints
Just add or subtract the null char (`'\0`).

### Comments
In 1d comments are supported with `#`, in 2d use a string then create a circular loop that has no outputs. E.g.

     "This is a comment"
    @?"This is too, the result is fed to the ? as the condition"
    ^@

Todo this might not work yet with the current type inference.

### Pow

Form a series of successive multiplications then take the nth one. E.g. 4 to the 5th power =

    [ } 5 a = : 1 * 4 a

Todo explain taking nth one.

### Reverse

    a = : "" !: "reverse me" a

or

    a = !: "reverse me" : "" a


### Appending two lists

Repeatedly cons to a list, starting from the other reversed.

    a = : "second" !: ]b = !: "first" : "" b a

### Concat

Repeatedly append.

    todo

### Map / Cartesian Product

### Filter

Map to an empty list or a singleton of the original element then concat.

### foldr

### Length

Map to 1s then sum. One way to map to 1s is to use an if/else of the element that always returns 1, if you want to make it fully lazy (first cons so that the value is always true without checking the value).

### Range 1..

Form the counting numbers then take n.

### Repeat

Simplest circular program

    a=1:a

### subscript / values_at

### equality checking

### index / find_indices by

### diff (list ops, ^ | & too)

### take while

### split

### join

### chunks of // n chunks

### step

### sort/by max_by

### chunk by

### group by

### transpose

### permutations

### subsequences

### nary cartesian product

### base conversion

### iterate / append until null
tuples
zipWith

### recursion

I don't have a general method for this, but I have figured out how to implement quicksort and mergesort.

# Tips

For complicated programs it might be helpful to define your own functions by modifying the interpreter (similarly to how todo is defined - written in Atlas1d). Then gradually manually inline this functions so you can delete them. It would be nice if Atlas1d supported custom functions, but that would kind of defeat the purpose of the language.
