
### Why multiple dispatch


Consider on might have a type from the **Ducks** library

```
struct Duck end

walk(self) = waddle(self)
talk(self) = println("Quack")

raise_young(self, child) = lead_to_water(self, child)
```

and I have a program, that I have written, that uses that library to simulate a farm:
```
function simulate_farm(adult_animals, baby_animals)
    for animal in adult_animals
        walk(animal)
        talk(animal)
    end

    parent = first(adult_animals)
    for child in baby_animals
        raise_young(parent, child)
    end
end
```

This works great with the `Duck`.
`simulate_farm([Duck(), Duck(), Duck()], [Duck(), Duck()])`

Now I want to extend it, to also work on `Swan`s.

```
struct Swan end
```
Now we try and use it:
`simulate_farm([Swan(), Swan(), Swan()], [Swan(), Swan()])`


walk(self::Swan) = waddle(self)
talk(self::Swan) = println("Hiss")

raise_young(self::Swan, child::Swan) = carry(self, child)
```


Since even though the code was written for `Duck`s,
a `Swan` **duck-types** as a `Duck`.
It `walk`s like a `Duck`, it basically `talk`s like a duck, etc.

Now, I want to have a mixed farm:

`simulate_farm([Duck(), Duck(), Duck()], [Duck(), Swan()])`

All seems well at first: some _Quacks_ and some _Hisses_.
But then, an Error!
There is no definition for `raise_young(parent::Duck, child::Swan)`
There is no way for the compiler to know what to do.
There is no meaningful way to duck-type these together.
We can't specify a useful way to convert a `Swan` to a `Duck` or a `Duck` to a `Swan`.

It is well-known that when a swan is left to be raised by ducks it just gets abandoned.

So one traditional (single dispatch) solution might be to update the `Duck`.

```
function raise_young(self::Duck, child::Any)
    if child isa Duck
        lead_to_water(self, child)
    elseif child isa Swan
        abandon(child)
    else
        error("$self does not know how to raise: $child")
    end
end
```

This has a key problem:

We had to edit the **Ducks** library to add `Swan` support.
The author of the **Ducks** library might not care about my need to simulate a farm with mixed poultry.
Adding `Swan` support could end up being a lot of code for them to maintain.
And if everyone does it, it starts to get really long,
with special cases for `Chicken`s `Geese` etc.
(and most direct solutions here look like an adhoc implementation of multiple dispatch.)

Slight alternative:
We could do it with a monkey-patch if the language supports that.
But now we are going to have to copy-paste the existing code,
and we will have to manually redo any updates etc.
Monkey-patching is generally frowned upon (and for good reasons.)

Alternative solution: Inheritance:

We create a new subtype of `Duck`: called `DuckWithSwanSupport`
```
function raise_young(self::DuckWithSwanSupport, child::Any)
    if child isa Swan
        abandon(child)
    else
        raise_young(upcast(Duck, self), child)
    end
end
```

But this too has a problem:
We need to replace every instance of a `Duck` type in our program,
with a `DuckWithSwanSupport` -- including those created in other libraries.
Maybe if all the code was written with dependency injection, rather than constructors then we can do that, but that is some serious engineering overhead if we wanted to roll it out globally for all types.

And again, if someone else wants to add `Chicken` support,
then they might make `DuckWithChickenSupport`,
but if we want to benefit from their code so we could support all 3, options are limited.
If you've solved multiple inheritance then you could make `DuckWithSwanAndChickenSupport` inherit from both -- but this is the classic diamond problem.

So this problem is not easy: we really want to chose which method to call based on both the first and second arguments.

The multiple dispatch solution is:
```
raise_young(parent::Duck, child::Swan) = abandon(child)
```

For completeness, Swans will kill ducklings, given the chance:
```
raise_young(parent::Swan, child::Duck) = kill(child)
```

---

The need to chose a method based on multiple arguments shows up all the time in scientific computing.
I suspect it shows up more generally, but we've learned to ignore it.

Consider Matrix multiplication.
We have
 - `*(::Dense, ::Dense)`: multiply rows by columns and sum. Takes $O(n^3)$ time
 - `*(::Dense, ::Diagonal)`/`*(::Diagonal, ::Dense)`: column-wise/row-wise scaling. $O(n^2)$ time.
 - `*(::OneHot, ::Dense)` / `*(::Dense, ::OneHot)`: column-wise/row-wise slicing. $O(n)$ time.
 - `*(::Identity, ::Dense)` / `*(::Dense, ::Identity)`: no change. $O(1)$ time.

Converting things to `Dense` in this case gives you the write answer, but much slower.
Converting `Dense` to structured sparse, just gives you the wrong answer.

If you look at a list of BLAS, LAPACK, etc. methods you will see just this,
but encoded not in the types of the input but in the function name.
E.g.
 - `SGEMM` - matrix matrix multiply
 - `SSYMM` - symmetric matrix matrix multiply
 - ...
 - `ZHBMV` - double complex - hermitian banded matrix vector multiply 

And turns out people keep wanting to make more and more matrix types.
 - Banded Matrixes
 - Block Matrixes
 - Block Banded Matrixes
 - Block Banded Block Banded Matrixs
    - where all the blocks are themselves block banded.

So its not a reasonable thing for a numerical language to say that they've enumerated all the matrix types you might ever need.

And that is before other things you might like to to to a Matrix.
Like run it on a GPU, or track its operations for AutoDiff purposes,
or give its dimensions names.
There are a number of very large array processing libraries out there that now have been reimplemented or hard-forked to just add this features.


---


