---
layout: default
title: "String Types in Julia"
tags:
    - julia
---

A shortish post about the various string type in Julia 0.6, and it's packages.
This post covers  `Base.String`, `Base.SubString`, `WeakRefStrings.jl`, `InternedStrings.jl`, `ShortStrings.jl` and `Strs.jl`;
and also mentioneds `StringEncodings.jl`.
Thanks to [Scott P Jones](https://github.com/ScottPJones), who helped write the section on his Strs.jl package.
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
Strs.jl is the only project I am aware of that is basically out to replace `Base.String` outright.

Strs.jl provides string types for valid ASCII, Latin1, UCS2, UTF-8, UTF-16, and UTF-32 encoded strings, Binary strings,
8-,16-,32-bit strings where the encoding is not known, and "raw" UTF-8 strings (like `String`, where the encoding is purportedly UTF-8,
but it is not necessarily valid.  There is also a type `UniStr`, which is meant to be used in place of `String`, which encodes the string
with 1, 2, or 4 byte codeunits, depending on the contents of the string.
Strs.jl's goals are to comply with the recommendations of the Unicode organization, IETF, and W3C in the handling of invalid strings
(to avoid known security exploits), to improve performance substantially (major gains are possible because of dealing with validated
strings), to provide greater flexibility (for handling other encodings, and for interfacing with other languages, libraries, and
file/database formats, with UTF-16 and UTF-32 support), easy to use (except for `UTF8Str` and `UTF16Str`, all of the `Str` string types
are indexed directly by characters, not codeunits), more robust (many of the bugs that continue to be found with `String` are caused by
the complexity of dealing with variable-length encodings, having to use `lastindex`, `thisind`, `nextind`, `prevind` correctly, or
consistency problems caused by allowing invalid characters (which means that `memcmp` cannot be used)), more functionality, a cleaner
API, and better memory utilization (UTF-8 takes a lot more space than UCS-2 for the languages of 3/4s of the world's population,
and more space than Latin1 for Western European languages).
Strs.jl also provides a `Chr` type, which is used to create a set of types, `ASCIIChr`, `LatinChr`, `UCS2Chr`, `UTF32Chr`, `Text1Chr`,
`Text2Chr`, `Text4Chr`, optimized for the characters in different string types. These are validated, and operating on them is much faster than using `Char`.
You can see [some outdated benchmarks here](https://discourse.julialang.org/t/ann-wip-strs-jl-package-ready-for-alpha-review-and-testing/8087/11).
The current version is now almost universally much faster than `Base.String`.

### Common Unicode Encodings
(This is not just relevant to Strs.jl, but as the main package being made for Unicode, it mostly is. When you start thinking about Unicode encodings while working in julia Strs.jl is almost certainly where you are going.)

ASCII and Latin1 (ISO-8859-1) are fixed width 1 byte encodings, which can be used to represent any of the characters in
Western European languages. ASCII is compatible with both UTF-8 and Latin1 encoding, which is a useful property when doing conversions.
It is a useful optimization (used by Python, Swift, and the Strs.jl package), to use 1-byte encodings when possible, and keep track of
whether a string is pure ASCII or not.
They are of-course theoretically really optimal if all your data can indeed be encoded in Latin1/ASCII;
being fixed-width and still rather supported by legacy applications and legacy data.

UTF-16 is variable width, with each character being either 1 or 2 2-byte codeunits.
UCS-2, for the purposes of this discussion, is UTF-16, with no surrogate characters present, such that all characters can be represented
in fixed size 2-bytes code, and O(1) to index, and O(1) to get the length of a string. It was claimed that >99% of the world's text can be
encoded using just the Unicode BMP (i.e. UCS-2) (while that may not be true if you are talking about text from Twitter or other chat apps,
where people frequently use Emojis)

One could say that UTF-16 is the worst of both worlds, or you could say it is a good middle ground.
[Microsoft really likes it](https://msdn.microsoft.com/en-us/library/windows/desktop/dd374081(v=vs.85).aspx) and to use the
[Windows API](https://msdn.microsoft.com/en-us/library/windows/desktop/dd374131(v=vs.85).aspx) you basically have to use it.
It is used as the internal format for many languages / libraries, because 1) it is significantly faster for processing than UTF-8
encoding, 2) by keeping track of whether a string only holds BMP characters, indexing operations and getting the length are O(1),
3) for many human languages (Asian, Indian, African ones in particular), UTF-8 takes 50% more space than UCS-2 / UTF-16, and for
languages that can be expressed using (non-ASCII) Latin, Hebrew, Arabic, Cyrillic characters, UTF-8 and UTF-16 take the same space.
It is used by many libraries with C/C++ APIs, such as ICU, many programming languages such as Java, Objective-C, Swift, Python, C#
as well as any based on JVM or .NET, and other heavily used ones.

UTF-32 takes 4 bytes per codeunit / character, and is faster to process (like ASCII, Latin1, UCS-2, and even UTF-16) than UTF-8, 
especially if you are using characters from outside the first 256 UTF-8 characters.
The encoding is trivial, O(1) to index and determine the length, however it suffers from taking more space than other encodings,
which can affect performance negatively, depending on the text. In general, it's best to use only when there are non-BMP characters
present in the string.

UTF-8 is a variable width encoding, from 1-4 bytes, where ASCII characters take up 1 byte, most non-ASCII characters in
European languages, Arabic, Hebrew, languages using the Cyrillic alphabet take 2 bytes (compared to 1 byte for Western European languages
using Latin1 encoding), most of the rest take 3 bytes (which would take only 2 bytes for UCS-2 or UTF-16), and non-BMP characters take
4 bytes per character, the same as both UTF-16 and UTF-32 encodings.
It is the best encoding for dealing with JavaScript, JSON, sending data to/from web applications, and external text files, although it is
not the best for doing text processing.  Processing it is fairly complex, and there are many possibly invalid sequences, including ones
which were valid prior to 2003, and those can be used for security exploits.



[LegacyStrings.jl](https://github.com/JuliaArchive/LegacyStrings.jl) also provides unicode string types,
however, I believe it is being maintained primarily for compatibility reasons.
Most things in JuliaArchive are not being maintained, and I suspect LegacyStrings will join them after julia 1.0.
Also as mentioned above one can use  [StringEncodings.jl](https://github.com/nalimilan/StringEncodings.jl) to convert between basdically any string encodings and the UTF-8 as implemented by `Base.String` during IO, if you just want to avoid the whole question (and just want the mostly good enough `Base.String`).
