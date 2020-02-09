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

There are a number of very large array processing libraries out there that now have been reimplemented or hard-forked to just add this features.


---


