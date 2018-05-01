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
If we ever finished getting [stack allocation for structs with heap references](https://discourse.julialang.org/t/stack-allocation-for-structs-with-heap-references/2293),
then WeakRefStrings.jl will likely be replaced with just using `SubString`.

## [InternedStrings.jl](https://github.com/oxinabox/InternedStrings.jl): `InternedString`


## [ShortStrings.jl](https://github.com/xiaodaigh/ShortStrings.jl): `ShortString{SZ}`

## [Strs.jl](https://github.com/JuliaString/Strs.jl)


[LegacyStrings.jl](https://github.com/JuliaArchive/LegacyStrings.jl) also provides unicode string types,
however, I believe it is being maintained primarily for compatibility reasons.
Most things in JuliaArchive are not being maintained, and I suspect LegacyStrings will join them after julia 1.0.
