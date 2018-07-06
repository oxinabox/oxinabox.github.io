---
title: These are a few of my Favourite Things (that are coming with Julia 1.0)
layout: default
tags:
   - julia
---

If I were more musically talented I would be writing a [song](https://www.youtube.com/watch?v=33o32C0ogVM)
♫ __Arguments that are destructured, and operator characters combine-ed; Loop binding changes and convert redefine-ed...__ ♫
 no none of that, please stop.

Technically speaking these are a few of my Favourite Things that are in julia 0.7-alpha.
But since since 1.0 is going to be 0.7 with deprecations removed,
We can look at it as a 1.0 list.

Many people are getting excited about big changes like
[Pkg3](https://docs.julialang.org/en/latest/stdlib/Pkg/),
[named tuples](https://github.com/JuliaLang/julia/issues/22194),
[field access overloading](https://github.com/JuliaLang/julia/issues/1974), 
[lazy broadcasting](https://docs.julialang.org/en/latest/manual/interfaces/#man-interfaces-broadcasting-1),
or the [parallel task runtime](https://github.com/JuliaLang/julia/pull/22631) (which isn't in 0.7 alpha, but I am hopeful for 1.0)
I am excited about them too, but I think they're going to get all the attention they need.
(If not then they deserve a post of their own each, not going to try and squeeze them into this one.)
Here are some of the smaller changes I am excited about.

These are excepts from [0.7-alpha NEWS.md](https://github.com/JuliaLang/julia/blob/v0.7.0-alpha/NEWS.md)
<!--more-->


### [Function argument De-structuring](https://github.com/JuliaLang/julia/issues/6614)

>Destructuring in function arguments: when an expression such as `(x, y)` is used as
a function argument name, the argument is unpacked into local variables `x` and `y`
as in the assignment `(x, y) = arg` ([#6614]).

This will mean the way I attempt to write do blocks with multiple arguments will work
`foo do (a,b)`

Also it makes the following work:

```julia
julia> foo((a,b), c) = (a+b)c
foo (generic function with 1 method)

julia> foo((1,2),3)
9
```

This is one of the more obscure python features that I missed when switching to julia.



### [Combining Characters in Operators](https://github.com/JuliaLang/julia/pull/22089)

> Custom infix operators can now be defined by appending Unicode
combining marks, primes, and sub/superscripts to other operators.
For example, `+̂ₐ″` is parsed as an infix operator with the same
precedence as `+` ([#22089]).

This means unlimited infix operations can be defined, without allowing some of the unread-ability that just letting words be used as infix would do.
Obviously should still be used with caution, and I think the need to use unicode will cause surficent caution and strike a good balance.
It should be understood that julia supporting editors (including vim and emacs) transform e.g. `\_2` into ₂ on a <kbd>tab</kbd>.
But still, that extra combination of key-presses I think will make people use them with caution.
Which should stop us seeing an unreadable mess.

Overall I'm not sure how often it will be used, but I think adding a subscript/superscript letter/number or two will show up.
Silly example:

```julia
julia> +₂(a,b) = sqrt(a^2 + b^2)
+₂ (generic function with 1 method)

julia> 1 +₂ 2
2.23606797749979
```

### [The missing value](https://github.com/JuliaLang/julia/pull/24653)

> The `missing` singleton object (of type `Missing`) has been added to represent
missing values ([#24653]). It propagates through standard operators and mathematical functions,
and implements three-valued logic, similar to SQLs `NULL` and R's `NA`.

It is kind of like `nan` for floating point numbers -- it propagates contaminating everything it touches.
But unlike `nan` it doesn't (semantically) represent a particular notion of mathematical/IEEE error,
but represents the notion of the data being in some sense missing.
It will hopefully make a lot of code clearer.

It becomes possible because of the small unions optimization.
One can contrast `Array(Union{Missing,T})` with  `DataArray{T}` from [DataArrays.jl](https://github.com/JuliaStats/DataArrays.jl), especially if you go back and look at the older tags.
One can also contrast `Array(Union{Nothing,T})` with `Array{Nullable{T}}` and `NullableArray{T}` from the deprecated [NullableArrays.jl](https://github.com/JuliaStats/NullableArrays.jl).

It will be interesting to see exactly how `nothing` and `missing` play out in-practice.
I feel like if all things go well, then in most circumstances operating with a `missing` should return a `missing` (i.e. propagation),
and operating with a `nothing` should throw an error (Much like a `NullReferenceError`).

### [Use begin blocks when defining enum values](https://github.com/JuliaLang/julia/pull/25424)

>Values for `Enum`s can now be specified inside of a `begin` block when using the
`@enum` macro ([#25424]).

Nice little QOL improvement:
Consider:

```julia
@enum Fruit apple=1 orange=2 kiwi=4
```

vs

```julia
@enum Fruit begin
	apple=1 
	orange=2
	kiwi=4
end
```

### [Constructors no longer falls back to convert](https://github.com/JuliaLang/julia/issues/15120)

>The fallback constructor that calls `convert` is deprecated. Instead, new types should
prefer to define constructors, and add `convert` methods that call those constructors
only as necessary ([#15120]).

Conversion and construction are not really the same thing at all.
And this will get rid of the long error message in:

```julia
julia> type Foo end

julia> Foo(2)
ERROR: MethodError: Cannot `convert` an object of type Int64 to an object of type Foo
This may have arisen from a call to the constructor Foo(...),
since type constructors fall back to convert methods.
Stacktrace:
 [1] Foo(::Int64) at ./sysimg.jl:77
```

### [Parse braces expressions like circumfix  operators](https://github.com/JuliaLang/julia/issues/8470)

> `{ }` expressions now use `braces` and `bracescat` as expression heads instead
    of `cell1d` and `cell2d`, and parse similarly to `vect` and `vcat` ([#8470]).
	
Everyone is familiar with infix operator overloading, and prefix operator overloading.
Julia actually has what  I would call  [circumfix](https://en.wikipedia.org/wiki/Circumfix)  operator overloading.
`[a b]` can be overloaded by overloading the `hcat` function.
`[a; b]` can be overloaded by overloading the `vcat`, function.
Normally these are used for arrays concatenation/construction.
But overloading them is cool, I do it in [TensorFlow.jl](https://github.com/malmaud/TensorFlow.jl/pull/209).
In TensorFlow.jl, this constructs nodes in the symbolic graph that perform the concatenations,
once the graph is executed.
I am using it right now in a project and it is fairly nice, espcially when combining with slicing syntax.

This is how I output colors in HSV.
It is better to train to [target the sin/cos of hue](https://stats.stackexchange.com/a/218547/36769),
so I need that in my graph.

```julia
Y_sat = nn.sigmoid(Y_logit[:,3])
Y_val = nn.sigmoid(Y_logit[:,4])
					
Y_hue_sin = tanh(Y_logit[:,1])
Y_hue_cos = tanh(Y_logit[:,2])
Y_hue_o1 = Ops.atan2(Y_hue_sin, Y_hue_cos)
Y_hue = reshape(Y_hue_o2, [-1]) # force shape, this I should fix
Y = [Y_hue Y_sat Y_val]
```

Anyway, to get back on point:
This language change means that braces (`{}`) can be overloaded in the same away.
They've basically been sitting there wasting since julia 0.4 when there use as Matlab-style cell arrays was replace by just having an array typed as `Any`.

Not sure I have any uses for it right now, but it open's up options.
There are a few other backet-type unicode characters, so maybe in the 1.x timeframe we might also be able to overload those as circumfix.
(and maybe use them for call/`getindex` type overload too).

### [For loop variable binding changes](https://github.com/JuliaLang/julia/issues/22314)

>  * In `for i = ...`, if a local variable `i` already existed it would be overwritten
during the loop. This behavior is deprecated, and in the future `for` loop variables
will always be new variables local to the loop ([#22314]).
The old behavior of overwriting an existing variable is available via `for outer i = ...`.
> * In `for i in x`, `x` used to be evaluated in a new scope enclosing the `for` loop.
Now it is evaluated in the scope outside the `for` loop.
>  * In `for i in x, j in y`, all variables now have fresh bindings on each iteration of the
innermost loop. For example, an assignment to `i` will not be visible on the next `j`
loop iteration ([#330]).

These are just nice.
Messing with your iteration variables of the for-loop leads to hard to read/comprehend code.
This makes it harder get any advantage out of doing so, so discourages people from doing it.

Also, [#330](https://github.com/JuliaLang/julia/issues/330) is the oldest issue closed by this release it is from 2012 -- about 6 years ago.
To this day there remains only [8 open issues older than it](https://github.com/JuliaLang/julia/issues?q=is%3Aissue+is%3Aopen+sort%3Acreated-asc).
Contrast the newest issue/PR number in this is [#27212](https://github.com/JuliaLang/julia/pull/27212),
an improvement to interface for matrix factorizations, written under 2 weeks ago.

### [ccall is now less magic in how it uses ampersand](https://github.com/JuliaLang/julia/issues/6080)

> Prefix `&` for by-reference arguments to `ccall` has been deprecated in favor of
`Ref` argument types ([#6080]).


`ccall` used to be really magic.
While  [\#18754](https://github.com/JuliaLang/julia/pull/18754) made it less so -- it is still pretty magic.
It looks like a function, but it is not a function at all, but an actual part of the language.
Notice from example that in both 0.6 and 0.7 it's first parameter needs to be resolve-able at compile time:
so

```julia

julia> ccall((Symbol("clock"), "libc"), Int32, ())
ERROR: TypeError: anonymous: in ccall: first argument not a pointer or valid constant expression, expected Ptr, got Tuple{Symbol,String}

julia> ccall((:clock, "libc"), Int32, ())
6978742
```

But at least with this change it doesn't use the  `&` operator entirely differently to the rest of the language.


### [Begin keyword in indexing expression](https://github.com/JuliaLang/julia/issues/23354)

> `begin` is disallowed inside indexing expressions, in order to enable the syntax
    `a[begin]` (for selecting the first element) in the future ([#23354]).

This isn't a 0.7 feature so much as a promise of a 1.x feature (hopefully 1.0).
Like we can say `x[end]` we'll be able to say `x[begin]`, not a huge advantage most of the time,
for single use we have `first`, and for standard arrays we can say `x[1]` but for arrays with unusual indexing, like in [OffsetArrays.jl](https://github.com/JuliaArrays/OffsetArrays.jl),
this will make code a lot clearer.

Consider being able to write `x[begin:2:end]` for every second element.


### [`@__DIR__` inside REPL now is same as `pwd()`](https://github.com/JuliaLang/julia/pull/21759)

> `@__DIR__` returns the current working directory rather than `nothing` when not run
from a file ([#21759]).

This is just nice, it is what you expect to happen.
[DataDeps.jl](https://github.com/oxinabox/DataDeps.jl) has some specialized code to deal with exactly this case.
(and said code had bugs, which I am not proud of considering it should be a simple work-around; but I was over using default arguments at the time.)

### [When promoting types, it is now an error if the types don't change](https://github.com/JuliaLang/julia/issues/22801)

> The `promote` function now raises an error if its arguments are of different types
and if attempting to convert them to a common type fails to change any of their types.
This avoids stack overflows in the common case of definitions like
`f(x, y) = f(promote(x, y)...)` ([#22801]).

This is good.
I encountered similar issues when writing this [line](https://github.com/JuliaMath/SpecialFunctions.jl/pull/18/files#diff-f839a13f2df5472f7fd840f52ce84e16R502), though it doesn't use promote.
The fact that you are hitting a `promote` at all, means that nothing accepting these argument types exists,
so if you're promoting them and not getting a new type, then there is no hope for you to find something better to do with them anyway.

### [Logging changes](https://github.com/JuliaLang/julia/issues/24490)

> The logging system has been redesigned - `info` and `warn` are deprecated
and replaced with the logging macros `@info`, `@warn`, `@debug` and
`@error`.  The `logging` function is also deprecated and replaced with
`AbstractLogger` and the functions from the new standard `Logging` library.
([#24490])

The new logging system, is really cool.
It is a lot prettier in the console for a start.
`@warn` includes a 1-line backtrace showing where it was triggered.
The whole system is configurable and extendable.
Its nice.

### [Getting the name of things is now easier](https://github.com/JuliaLang/julia/pull/25622)

> `module_name` has been deprecated in favor of a new, general `nameof` function. Similarly,
    the unexported `Base.function_name` and `Base.datatype_name` have been deprecated in favor
    of `nameof` methods ([#25622]).
	
It was annoying not having `Base.function_name` and  `Base.datatype_name`  exported.
I kept forgetting how to do it, and having around inside fields of the type.
	
	
### [Explicit imports via using now has just one syntax](https://github.com/JuliaLang/julia/issues/8000)

>The syntax `using A.B` can now only be used when `A.B` is a module, and the syntax
`using A: B` can only be used for adding single bindings ([#8000]).

I've never been a fan of [TMTOWTDI](https://en.wikipedia.org/wiki/There%27s_more_than_one_way_to_do_it).
While julia is a TMTOWTDI language, there is no need to be excessive.
As they say TIMTOWTDIBSCINABTE.



### [Also `importall` is gone](https://github.com/JuliaLang/julia/issues/22789)

>  * The keyword `importall` is deprecated. Use `using` and/or individual `import` statements
    instead ([#22789]).
    
This is good, it was generally a bad-idea, and I don't know anyone who was using it seriously.
It is easy enough to recreate with some metaprogramming and `names(::Module, true)`.



### [Non-recursive transpose is now done with permutedims](https://github.com/JuliaLang/julia/pull/24839)

>`permutedims(m::AbstractMatrix)` is now short for `permutedims(m, (2,1))`, and is now a
more convenient way of making a "shallow transpose" of a 2D array. This is the
recommended approach for manipulating arrays of data, rather than the recursively
defined, linear-algebra function `transpose`. Similarly,
`permutedims(v::AbstractVector)` will create a row matrix ([#24839]).

Good, being unable to transpose arrays of strings in 0.6 (without giving dims) was annoying.
No more:

```julia
julia> ["alpha" "omega"]'
1×2 RowVector{Any,ConjArray{String,1,Array{String,1}}}:
Error showing value of type RowVector{Any,ConjArray{String,1,Array{String,1}}}:
ERROR: MethodError: no method matching transpose(::String)

julia> #err no mistakes have been made, that hasn't worked since 0.5
	   
julia> reshape(["alpha", "omega"], (:,1) )
2×1 Array{String,2}:
 "alpha"
 "omega"
 
julia> ["alpha" "omega"; "beta" "gamma"]'
ERROR: MethodError: no method matching transpose(::String)

julia> # Oh No. mistakes have been made, AGAIN, that hasn't worked since 0.5

julia> permutedims(["alpha" "omega"; "beta" "gamma"], (2,1))
2×2 Array{String,2}:
 "alpha"  "beta"
 "omega"  "gamma"
```

0.6 used `reshape` to transpose vectors of strings, and `permutedims` to transpose matrices of strings.

Now we can just do `permutedims` without specifying the dims for both.

```
julia> permutedims(["alpha", "omega"])
1×2 Array{String,2}:
 "alpha"  "omega"
 
julia> permutedims(["alpha" "omega"; "beta" "gamma"])
2×2 Array{String,2}:
 "alpha"  "beta"
 "omega"  "gamma"
```

Not quiet as brief as a apostrophe, but still `permutedims` for both is a lot clearer.
And this means we are [taking transpose seriously still (read these 417 comments, over 3 years to know what that means)](https://github.com/JuliaLang/julia/issues/4774).


### [Most functions that create or modify a file/folder return the path](https://github.com/JuliaLang/julia/pull/27071)

 >  * `mv`,`cp`, `touch`, `mkdir`, `mkpath`, now return the path that was created/modified
    rather than `nothing` ([#27071]).
	
This is my only real contribution to `Base` in the 0.7 timeframe.
It is just one of those tiny "I assumed it always worked that way" things that are technically breaking changes, that are good to get in before they become blocked until Julia 2.0.

### [Iterator Changes](https://github.com/JuliaLang/julia/pull/25261)
These seem to be missing from the change log, but they are going to make a whole lot of iterators easier to define.


In 0.6 one had to define 3 functions:

 -  `start(iterable)` which returned the initial `state`
 -  `next(iterable, state)` which return `(element, newstate)`
 -   and `done(iterable, state)` returning a boolean to indicate if done.
 
This often mean one would have to read-ahead and store future element in the state so that one could check if a source was going to be empty when done was called.
It was an annoying pattern. 
The changes proposed in [Julep #18823](https://github.com/JuliaLang/julia/issues/18823) are now in.

Now there is just one function `iterate`
  - `iterate(iterable)` returns the initial `state` and the  first element (basically same as `start` + `next` combined)
  - `iterate(iterable, state)` returns the `newstate` and the  next element (basically same as `next`)
  - However both the 1-arg and 2-arg forms return `nothing` when there are no more items (i.e. what uesd to be check for in `done`.)
This is going to make a lot of code easier to write.

See the [docs](https://docs.julialang.org/en/latest/manual/interfaces/#man-interface-iteration-1),
and [Eric Davies excellent blog post on the changes](https://invenia.github.io/blog/2018/07/06/iteratorsinjulia07/)

### [More pure julia math](https://github.com/JuliaLang/julia/issues/26434)

It's not in the changelog, because it is basically invisible to users,
but thanks to the work of [@pkofod](https://github.com/pkofod) and several others,
julia is now really close to not shipping with a C based math library.
A pure julia math library at the lowest level.
I suggested [that here](https://github.com/JuliaLang/julia/issues/18102#issuecomment-240618613),
though I am sure I wasn't the first to suggest it.
It will be much nicer to maintain,
and I think, given the people working with julia, will in time exceed(/become) the state of the art, in performance and accuracy.
(To my knowledge there are no speed regressions with this change, so it can only get better.)


Julia 0.7-alpha is still shipping [openlibm](https://github.com/JuliaLang/openlibm).
There is a solid chance that 1.0 won't, and if not 1.0 then definitely gone in the 1.x timeframe.


### [Compiler/Runtime improvements](https://github.com/JuliaLang/julia/pull/22210)

> * The inlining heuristic now models the approximate runtime cost of
a method (using some strongly-simplifying assumptions). Functions
are inlined unless their estimated runtime cost substantially
exceeds the cost of setting up and issuing a subroutine
call. ([#22210], [#22732])
>* Inference recursion-detection heuristics are now more precise,
allowing them to be triggered less often, but being more agressive when they
are triggered to drive the inference computation to a solution ([#23912]).
>* Inference now propagates constants inter-procedurally, and can compute
various constants expressions at compile-time ([#24362]).

I love me some optimizations.
My code, becoming just faster, without me doing anything about it?
What is not to like about that?

From what I hear there will be a lot of optimization work being done in the 1.x timeframe.
Since the language itself will not be changing so much anymore.



### Conclusion

So yes,
these are a few of my favourite things in julia 0.7-alpha, and thus what I anticipate for Julia 1.0.
It is a big release, 
there are a whole lot more things that I've not included in this list.
But they might be a few of your favourite things.
Here is the link to the [NEWS.md again](https://github.com/JuliaLang/julia/blob/v0.7.0-alpha/NEWS.md)
