---
layout: default
title: "String Types in Julia"
tags:
    - julia
---

A shortish post about the various string type in Julia 0.6.

<!--more-->

All strings are subtypes of `AbstractString`,
which provides most of the functionality.

## Base: `String`
The standard string type is `String`.
This is an UTF8 string.
It is immutable, and in memory is is a pointer-type 
(This is in-contrast to `struct`s which are immutable value types, and `mutable struct`s which are mutable pointer-types.)
It is binary compatible with `C`, it is null-terminated.
But it also records the length along-side.

If you want to read or write non-UTF8 strings,
use [StringEncodings.jl](https://github.com/nalimilan/StringEncodings.jl).
That will let you load and write strings in any encoding and any codepage.
It is really easy to use, especially if you are willing for them to  be converted to UTF8 during loading.
(At one point IIRC in 0.3, it was impossible to load non-UTF8 strings, and it was bad, but StringEncodings.jl make that easy.)

## Base: `SubString`
`SubString` is the other string type included in Base.
It is returned by the `substring` function, and by other functions such as `split`, and various regex matching.
It holds a reference to the original string, as well as an offset and a length recording.
This saves on allocating memory for the split-up string.
However, that reference to the "parent" string, is a real reference.
While the substring is referenced, the parent string can not be garbage collected.
Further, if the substring is serialised (either to disk, or over the network via e.g. `pmap`),
the parent string also must be serialised.
I've been caught out by that a few times, wondering why my vocabulary set, containing just 10,000 unique words
is >5GB on disk, only to open up the serialised JLD file and find the whole corpus is stored along side it, to resolve that reference.



## [WeakRefStrings.jl](https://github.com/JuliaData/WeakRefStrings.jl): `WeakRefString`

WeakRefStrings.jl are not really for casual users.
They are more or less just like `SubString`s except that they have only a weak reference to the parent string.
This means that holding a reference to the WeakRefString will not prevent the parent string from being garbage collected.
At which point trying to read the WeakRefString will likely result is garbage or crashing with a segfault.
They true advantage of not having a strong reference is that it allows the WeakRefString to be stack allocated.
Right now, if a composite type has an actual (strong) reference (like in `SubString`) it will always be allocated on the heap.
Which is slower, and has garbage collection related things.
If we ever fully get [stack allocation for structs with heap references](https://discourse.julialang.org/t/stack-allocation-for-structs-with-heap-references/2293),
then WeakRefStrings.jl will likely be replaced with just using `SubString`.

## [InternedStrings.jl](https://github.com/oxinabox/InternedStrings.jl): `InternedString`

v0.4 of InternedStrings.jl introduces a type `InternedString`
which represents a `String` that has been [interned](https://en.wikipedia.org/wiki/String_interning).
InternedStrings have the property that only a single unique instance for a given string's content exists.
All instances of such a string are just references to the same data.
When the last reference is gone, that string can/will be garbage collected.

In the upcoming (proposed) [v0.5.0](https://github.com/oxinabox/InternedStrings.jl/pull/9) it does the same thing,
except that it no longer has a type associated with it.
One simply called `intern(str)` on the string type of choice and it either gives back a reference to a copy from the pool; or adds it to the pool (and acts as the identity).
Because of these changes v0.5.0 of InternedStrings is compatible with (basically) any string type.
Further, because it is not doing an allocation for the wrapper type, it is really fast
(and it wasn't crazy slow before), and uses even less memory.

Interning strings has a solid advantage if you are going to be dealing with a lot of copies of the same string.
Which is common in natural language tokenization because of [Zipf's law](https://en.wikipedia.org/wiki/Zipf%27s_law),
particularly if one eliminates the rare words.

The other thing it gets you is really fast equality checking, since if two interned strings are not the same reference then they can't be equal.
In InternedStrings.jl v0.4 this applies to all checks since it overloads `==` into `===`.
In v0.5 this will have to be done explicitly via `===`.
(It might be worth defining `intern_eq(a,b)= a===b || intern!(a)==intern!(b)` or similar)



## [ShortStrings.jl](https://github.com/xiaodaigh/ShortStrings.jl): `ShortString{SZ}`

Since a String in julia is binary just like a string C,
that means it has a pointer to character memory, and that memory then contains the content.
On a 64bit build that pointer has 8 bytes, (4 bytes on 32bit).
For you can store a significant number of words in 8 bytes.
Pointer indirection takes time.

ShortStrings.jl does strings without pointers, where all the values are inline.
It does this by basically reinterpretting the binary data behind a primitive type, per byte.
It thus provides strings in  3 sizes:
`ShortString15` ontop of a `UInt128`, able to hold up to 15 bytes.
`ShortString7` ontop of a `UInt64`, able to hold up to 7 bytes.
`ShortString3` ontop of a `UInt32`, able to hold up to 3 bytes.
If your cointing bytes, you'll see the obvious question of "where is the extra byte going?".
The last byte of the memory is used to store the length of the string.
(The actual length, not the maximum length).


## [Strs.jl](https://github.com/JuliaString/Strs.jl)

Strs.jl provides string types for valid ASCII, Latin1, UCS2, UTF-8, UTF-16, and UTF-32 encoded strings.
As well as types that can contain invalid data that generally looks like the above, but is not necessarily valid.
Rather than taking the approach of `Base.String` of only handling UTF-8, 
and also allowing the String type to contain invalid UTF-8.
Strs.jl's main purpose is to be more correct in following Unicode,
while also getting performance gains.
You can see [some outdated benchmarks here](https://discourse.julialang.org/t/ann-wip-strs-jl-package-ready-for-alpha-review-and-testing/8087/11).
Apparently the current version is now almost universally much faster that `Base.String`.


UTF-32 has in theory pretty serious performance (speed) advantages over UTF-8.
Especially if you are using characters from outside the first 256 UTF-8 characters.
In UTF-32 all characters are 4 bytes -- no variation.
So it is trivial, O(1) to index,
although the extra-size does presumably cost one on CPU cache etc which can result in some slowness.

UCS2 is similar in advantages to UTF-32, also being fixed width at 2 bytes (It is however considered to be obsolete, no longer being included in the Unicode standard.)
Latin1 and ASCII are fixed width 1 byte encodings; however at that size, it is obvious that one has a very limited number of characters to work with.
They are of-course theoretically really optimal if all your data can indeed be encoded in Latin1/ASCII;
being fixed-width and still rather supported by legacy applications and legacy data.

UTF-16 is variable width, with each character being either 2 or 4 bytes.
One could say that is is the worst of both worlds, or you could say it is a good middle ground.
[Microsoft really likes it](https://msdn.microsoft.com/en-us/library/windows/desktop/dd374081(v=vs.85).aspx) and to use the [Windows API](https://msdn.microsoft.com/en-us/library/windows/desktop/dd374131(v=vs.85).aspx) you basically have to use it.

UTF-8 is the coding that is really for all normal use. Variable width with characters taking between 1 and 4 bytes.


[LegacyStrings.jl](https://github.com/JuliaArchive/LegacyStrings.jl) also provides unicode string types,
however, I believe it is being maintained primarily for compatibility reasons.
Most things in JuliaArchive are not being maintained, and I suspect LegacyStrings will join them after julia 1.0.
