---
title: Julia 1.6 - what has changed since Julia 1.0?
layout: default
tags:
   - julia
---

Julia 1.6 is slated to be the next long-term support release of the Julia programming language.
It has been 2 years since the last LTS, and a lot has changed.
This post is kind of a follow-up to my [Julia 1.0 release run-down]({{site.url}}//2018/06/01/Julia-Favourite-New-Things.html).
But it's going to be even longer, as it is covering the last 5 releases since then.
I am writing this not to break down release by release,
but to highlight features that had you only used Julia 1.0, you wouldn't have seen.
Full details can be found in the NEWS.md, and HISTORY.md
TODO: Insert links to the files in the release-1.6 branch.


## Threading
Julia has full support for threading now.
Not just the limited `@threads for` loops, but full GoLang style threads.
They are tightly integrated with the existing Task/Coroutine system.
In effect threading works by unsetting the sticky flag on a task, so that it is allowed to run on any thread.
This is normally done via the `Threads.@spawn` macro, rather than the `@async` macro.

Interestingly, the `@threads for` macro still remains, and doesn't actually use much of the new machinery. It still uses the old way which is a bit tigher if the loop durations are almost identical.
But the new threading stuff is fast, on the order of microseconds to send work off to another thread.
Even for uses of `@threads for` the improves have some wins.
`IO` is now thread-safe; `ReentrantLock` was added and is the kind of standard lock that you expect to exist, that has notifications on waiting work etc; and a big one: `@threads for` can now be nested without things silently being wrong.

A lot of this actually landed in julia 1.2, but julia 1.3 was the release we think of as being for threading, as it gave us `Threads.@spawn`.

Also in Julia 1.6 we now have `julia -t auto` to start julia with 1 thread per (logical) core.
No more having to remember to set the `JULIA_NUM_THREADS` environment variable before starting it.


## Pkg stdlib and the General Registry
Writing this section is a bit hard as there is no NEWS.md nor HISTORY.md for the Pkg stdlib; and the general registry is more policy than software.

TODO: Write bits for these:
 - Full transition off METADATA
 - Automatic merging
 - Pkg Server: faster updating of registry and download of packages
 - Artifacts, BinaryBuilder, Yggdasil, almost no one uses `deps/build.jl` any more
 - Scratch, and Preferences
 - Tiered Resolution: in particular solving test dependencies of different compat.
 - `activate --temp`
 - test dependencies
 - passing arguments to Pkg.test

### Precompilation

Precompilation has been enhanced a lot.
That is not the compilation that runs the first time a function is used in a session, but rather the stuff that runs the first time a package is loaded in an environment.

For a start, the precompilation cache no longer goes stale every time you swap environments.
This was a massive pain in julia 1.0, especially if you worked on more than one thing at a time.
This was fixed in 1.3 to have multiple caches, for different environments.

More dramatically, in 1.6 is the parallelism of precompilation.
Precompiling a package requires precompiling all its dependencies first.
This is now done in parallel, and is automatically triggered when you complete Pkg operations.
In contrast, to happening in series the first time a package is loaded.
No more waiting 5 minutes the first time you load an package with a lot of dependencies.
Further the spiffy animated output shows you what is precompiling at a given time; and a progress bar, which makes it feel (even) faster.

<script id="asciicast-a26toW3opklSEtaRAeXzpcW8W" src="https://asciinema.org/a/a26toW3opklSEtaRAeXzpcW8W.js" async></script>

### Improved conflict messages
This is one of my own small contributions.
Julia 1.0 conflict messages are a terrifying wall of text.

<img href="{{site.url}}/Julia-1.0-1.6-changes/julia1.0-conflict.png">Julia 1.0 conflict log</img>
<img href="{{site.url}}/Julia-1.0-1.6-changes/julia1.6-conflict.png">Julia 1.6 conflict log</img>

Colors were added to make it easier to see which version numbers are referring to which package.
Consecutive lists of version numbers were compressed to continuous ranges.
In 1.6 these ranges are split only if there is a version that exist between them that is not compatible.
In contrast in 1.0, they were split if there was a potential version that could exist that is not compatible (even if that version doesn't currently exist); in practice this mean they split every time the right most nonzero was incremented.

## Standard Library

### 5-arg `mul!`, aka in-place generalized multiplication and addition
The 5 arg `mul!(C, A, B, α, β)` performs the operation equivalent to: `C .= A*B*α + C*β`, where `α`, `β` are scalars and `A`, `B` and `C` are compatible mixes of scalars, matrices and vectors.
I am still the opinion that it should have been called `muladd!`, but this is the human friendly version of `BLAS.gemm!` (i.e. GEneralized Matrix Multiplication) and it's ilk.
It promises to alway compute the in-place mul-add in the most efficient, correct, way for any `AbstractArray` subtype.
In contrast, `BLAS.gemm` computes the same thing, but with a bunch of conditions.
It must be a strided array containing only BLAS-scalars, and if one of the inputs is conjugated/transposed you need to input it in non-conjugated/transposed form, and then tell `BLAS.gemm!` via passing in `'C'` or `T` rather than `N`.
5-arg `mul!` takes care of all that for you dispatching to `BLAS.gemm!` or other suitable methods once it has that all sorted.
Further, the existing 3-arg `mul!(C, A, B)` is a special case of it:
`mul!(C, A, B) = mul!(C, A, B, false, true)` (`true` and `false` being 1, and strong 0).
So in general on can just implement the 5-arg form and be done with it.

I personally didn't care about 5-arg `mul!` at all for a long time.
Yet another in-place function in `LinearAlgebra` that I would never use often enough to remember what it did, and thus wouldn't use it.
But I realized that it is a crucial function for my own area: automatic differentiation.
`mul(C, A, B, true, true)` is the in-place accumulation rule for the reverse mode equivalent of the product rule.


### You can now print and interpolate `nothing` into strings.

This is one of mine [#32148](https://github.com/JuliaLang/julia/pull/32148)., and I find it is such a usability enhancement.
So many small frustrations in Julia 1.0 relating to interpolate a variable containing `nothing` into a string.
Often occurring when you are adding a quick `println` to debug something not being the value you expected; or when building a string for some other error message.
Arguably both of those are better done via other means (`@show`, and values stored in fields in the error type); but we don't always do what is best.
Sometimes it is expedient to just interpolate things into strings without worrying about what type they are.


### A bunch of curried functions
Julia seems to have ended up with a convention of providing curried methods of functions if that would be useful as the first argument for `filter`.
e.g. `filter(isequal(2), [1,2,3,2,1])`, is the same is `filter(x->isequal(x, 2), [1,2,3,2,1]`).
In particular these are boolean comparison like functions:
with two arguments, where the thing being compared against is the second.
Julia 1.0 had `isequal`, `==` and `in`.
Since then we have added:
`<`,`<=`,`>`, `>=`, `!=`, `startswith`, `endswith`, and `contains`.
(I added the last 3 😁)


Aside: `contains` is argument flipped `occursin`, it was a thing in julia 0.6 but was removed in 1.0.
We added it back expressly to have the curried form, and to match `startswith` and `endswith`.

## A ton of new and improved standard library functions:

[`@time`])(https://github.com/JuliaLang/julia/pull/37678) now reports how much time was spent on compilation.
This is going to help prevent people knew the language from including compilation time in their benchmarks.
It is still better to use [BenchmarkTool.jl's](https://github.com/JuliaCI/BenchmarkTools.jl) `@btime`, since that does multiple samples.
But now that too can report time spend compilation.
It's also useful for identifying if certain functions are taking ages to compile.
Which I guess is its theoretical main point, but I think preventing people benchmarking wrong is going to come up way more often.

The experimental [`Base.@locals`](https://github.com/JuliaLang/julia/issues/29733
) was added which returns a dictionary of local variables.
That one surprised me, I though being able to access a dict of local variables would get in the way of the optimizer, since it would prevent it from being able to optimize variables that are used for intermediate values away entirely.
But the compiler folk know better than I do.

[`splitpath`](https://github.com/JuliaLang/julia/issues/28156) as added, its the opposite of `joinpath`.
Kind of stilly we didn't have that, and had been being me at least since 0.6.

On things that had been bugging me, I had wanted [`eachslice` and it's special cases: `eachrow` & `eachcol`](https://github.com/JuliaLang/julia/issues/29749) since julia 0.3 when I first started using it.
These are super handy when you want to e.g. iterate through vectors of the rows of a matrix.


`redirect_stderr` and `redirect_stdout` now work with `devnull`.
So one can run some suppressing output easily as follows:
```julia
julia> redirect_stdout(devnull) do
       println("You won't see this")
       end
```
This is just handy, doing it without this is seriously annoying.


## More "Why didn't it always work that way" than I can count
Since 1.0's release there have been so many small improvements to functions that I didn't even know happened, because I assumed they always worked that way.
Things like `startswith` supporting regex.





