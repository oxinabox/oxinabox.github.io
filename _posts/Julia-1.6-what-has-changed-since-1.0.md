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
They are tightly integrated with the existing Async/Task/Coroutine system.
In effect threading works by unsetting the sticky flag on a Task, so that it is allowed to run on any thread.
This is normally done via the `Threads.@spawn` macro, rather than the `@async` macro.

Interestingly, the `@threads for` macro still remains, and doesn't actually use much of the new machinery. It still uses the old way which is a bit tigher if the loop durations are almost identical.
But the new threading stuff is fast, on the order of microseconds to send work off to another thread.
Even for uses of `@threads for` the improves have some wins.
`IO` is now thread-safe; `ReentrantLock` was added and is the kind of standard lock that you expect to exist, that has notifications on waiting work etc; and a big one: `@threads for` can now be nested without things silently being wrong.

A lot of this actually landed in julia 1.2, but julia 1.3 was the release we think of as being for threading, as it gave us `Threads.@spawn`.

Also in Julia 1.6 we now have `julia -t auto` to start julia with 1 thread per (logical) core.
No more having to remember to set the `JULIA_NUM_THREADS` environment variable before starting it.

## NamedTuple/keyword arguments automatic naming
This feature felt weird when I first read about it, but it has quickly grown on me.
How often do you write some code that does some processing and calls some other method passing on some of its keyword arguments?
For example
```julia
# Primary method all others redirect to this
foo(x::Bar; a=1, b=2, c=3) = ...

# Method for if x is given as components
foo(x1, x2; a=10, b=20, c=30, comb=+) = foo(Bar(comp(x1, x2)); a=a, b=b, c=c)
```
This new feature allows one to avoid writing `(...; a=a, b=b, c=c)`, and instead write `(...; a, b, c)`.
This does come with the requirement to seperate keyword arguments from positional arguments by `;`, but I have always done this, and the [BlueStyle guide requires it](https://github.com/invenia/BlueStyle#keyword-arguments).
It feels like we are fully leveraging the distinction of keyword from positional arguments by allowing this.
(In contrast, the distinction vs e.g. C# and Python that allow any positional argument to be passed by name, is to make the name of positional arguements not part of the public API, thus avoiding changing it being a breaking change.)

The same syntax can be used to create `NamedTuple`.
```julia
julia> product = ["fries", "burger", "drink"];

julia> price = [2, 4, 1];

julia> (;product, price)
(product = ["fries", "burger", "drink"], price = [2, 4, 1])
```
This is particularly cool for constructing `NamedTuple`s of `Vector`s, which is a valid [Tables.jl Table](https://tables.juliadata.org/stable/#Tables.columntable).

## Performance
### References to the Heap from the Stack
This was promised in 2016 as a feature for 1.0 (released 2018).
But we actually didn't get it til 1.5 with [#33886](https://github.com/JuliaLang/julia/issues/33886).
Basically, the process of allocating memory from the heap is fairly slow*, where as allocating memory on the stack is basically a non-op.
Indeed Julia benchmarking tools don't count allocations on the stack as allocations at all.
One can find extensive write ups of heap vs stack allocations and how it works in general (though some mix the C specific factors with the CPU details.)
In julia all mutable objects live are allocated on the heap.
Until recently, immutable objects that contained references to heap allocated objects also had to live on the heap.
i.e. immutable objects with immutable fields (with immutable fields with...) could live on the stack.
But with this change now all immutable object can live on the stack, even if some of their fields live on the heap.
An important consequence of this is that wrapper types, such as the `SubArray` returned from `@view x[1:2]`, now have no overhead to create.
I find that in practice this often adds up to a 10-30% speed-up in real world code.

(* Its actually really fast, but it is the kind of thing that rapidly adds up; and its slow vs operations that can happen without touching RAM.)

### Invalidations

## Front-end changes
### Soft-scope in the REPL
### Deprecations are muted by default.

This was me in [this PR](https://github.com/JuliaLang/julia/pull/35362).
It's not something I am super-happy about.
Though I think it makes sense.
Using deprecated methods is actually fine, as long as your dependencies follow SemVer, and you use `^` (i.e. default) bounding in your Project.toml's `[compat]`.
Which everyone does, because its enforced by the auto-merge script in the General registry.

Solving deprecations is a thing you should chose to do, actively.
Not casually, when trying to do something else.
In particular, when updating to support a new major release of one of your dependencies, you should run your (integration) tests to see if they succeed.
If they don't succeed, then one removed support for the new version and run julia with deprecation warnings turned on (or set to error); to identify and fix them.
Probably also you are checking the release notes, since you are intentionally updating.

The core of the reason is because it was actually breaking things.
Irrelevant deprecation warning spam from dependencies of dependencies was causing JuMP and LightGraphs to become too slow to be used.
Since they were from dependencies of dependencies the maintainers of those JuMP and LightGraphs couldn’t even fix them.
Let alone the end users.

Deprecation warnings are still turned on by default in tests.
Which makes sense since the tests (unlike normal use), is being run by maintainers of the package itself, not its users.
Though it still doesn't make a huge amount of sense to me, since spam from deprecation warnings floods out your actual errors that you want to see during testing.
For this reason Invenia (my employer) has disabled deprecation warnings in the tests for all our closed source packages, and added a new test job that just does deprecation checking (set to error on deprecation and with the job allowed to fail, just so we have notice).

Hopefully one day we can improve the tooling around deprecation warnings.
An ideal behavour would be to only show deprecation warning if directly caused by a function call made from within the package module of your current active environment.
I kind of know what we need to do to the logger to make that possible.
But it is not yet something I have had time to do.

### Colored Stack-traces
TODODODOTOTOTOTODODEOEDO TODO

## Pkg stdlib and the General Registry
Writing this section is a bit hard as there is no NEWS.md nor HISTORY.md for the Pkg stdlib; and the general registry is more policy than software.

TODO: Write bits for these:

 - Pkg Server: faster updating of registry and download of packages
 - Artifacts, BinaryBuilder, Yggdasil, almost no one uses `deps/build.jl` any more
 - Scratch, and Preferences
 - `activate --temp`
 - test dependencies. https://discourse.julialang.org/t/activating-test-dependencies/48121/7?u=oxinabox
 - passing arguments to Pkg.test

### Full Transition off METADATA.jl and REQUIRE files, and onto the General Registry
Even though Julia 1.0 had Pkg3 and was supposed to use registries, for a long time the old Pkg2 [METADATA.jl](https://github.com/JuliaLang/METADATA.jl) pseudo-registry was used as the the canonical source of truth.
Registering new releases was made against that, and then a script synchronized [General](https://github.com/JuliaRegistries/General) registry to match it.
This was to allow time for packages to change over to supporting julia 1.0, while still also making releases that supported julia 0.6.
It wasn't until about a year later that this state ended and the General registry became the one source of truth.

This was kind of sucky, because a lot of the power of Pkg3 was blocked until then.
In particular, since the registries compat was generated from the REQUIRE file, and the REQUIRE files had kind of [gross requirement specification](https://docs.julialang.org/en/v0.6/manual/packages/#Requirements-Specification-1), and everyone basically just lower bounded things, or didn't bound compat at all.
Which made sense because with the only 1 global environment that Pkg2 had, you basically needed the whole ecosystem to be compatible, so restricting was bad.
But Pkg3/Project.toml has the much better default [`^` bounded]](https://julialang.github.io/Pkg.jl/v1/compatibility/#Version-specifier-format-1) to accept only non-breaking changes by SemVer.
(And per project environments, so things don't all have to be compatible -- just things used in a particular project (rather than every project you might ever do).

#### Automatic Merging
Initially after the change over all PRs to make a new release needed manual review, by one of the very small number of General registry maintainers.

I am a big fan of [releasing after every non-breaking PR](https://www.oxinabox.net/2019/09/28/Continuous-Delivery-For-Julia-Packages.html).
Why would you not want those bug-fixes and new features released?
It is especially rude to contributors who will make a fix or a feature, but then you don't let them use it because you didn't tag a release.
Plus it makes tracking down bugs easier, if it occurs on a precise version you know the PR that caused it.
But with manual merging it feels bad, to tag 5 releases in a day.
Now they we have automatic merging it is fine.
At time of writing [ChainRules.jl](https://github.com/JuliaDiff/ChainRules.jl/) was up to 67 releases.

The big advantage of automatic merging is that it comes with automatic enforcement of standards.
In order to be automerge-able some good standards have to be followed.
One of which is that that no unbounded compat specifiers (e..g `>=1.0`) are permitted; and that everything must have a compat specifier (since unspecified is same as `>=0.0.0`)
That one is particularly great, since if one adds specifiers later that can't be met, then it can trigger downgrades back to the incredible old versions that didn't specify compat and that almost certainly are not compatible.

To deal with that particular case retro-capping was done to retroactively add bounds to all things that didn't have them.
Which was painful when it was done, since it rewrote compat in the registry, which made it disagree with the `Project.toml`, which is always confusing.
Now that it is done, it is good.

#### Requirement to have a `Project.toml`
Finally the ability to `pkg> dev` packages that had only a REQUIRE and no `Project.toml` was removed in Julia 1.4.
You can still `pkg> add` them, if they were registered during the transition period.
But to edit the projects they must a `Project.toml` file, which is fine since all the tools to make registering releases also require you to have `Project.toml` now



### Resolver willing to downgrade packages to install new ones (Tiered Resolution)

Until the [tiered resolver](https://github.com/JuliaLang/Pkg.jl/pull/1330) was added Julia would not change the version of any currently installed package in order to install a new one.
For example consider

 - **Foo.jl**
	 - v1
	 - v2
 - **Bar**
	 - v1 compatible with Foo v1
	 - v2 compatible with Foo v2
 - **Qux.jl**
	 - v1: compatible only with Foo v1

If you did `pkg"add Foo Bar Qux"` you would end up with **Foo** v1, **Bar** v1, and **Qux** v1.
But if you did first: `pkg"add Foo Bar"` (which would install  **Foo** v2, and **Bar** v2),
and then did `pkg"add Qux"`,
then on Julia 1.0 you would get an error, as it would refuse to downgrade **Foo** and **Bar** to v1, as is required to allow **Qux** to be installed.
This meant effectly the package manager is stateful, which turns out is really counter intuitive.
The way to resolve this in practice was to delete the `Manifest.toml` and do it again as a single action.
This was a significant problem for [test time dependencies](https://github.com/JuliaLang/Pkg.jl/issues/1352), which if you had a test time dependencies with a indirect dependencies shared with a main dependency of the package, but that was only compatible with an older version of the indirect depenency, you would be unable to run tests as resolving the test time depenency would fail.

With the new tiered resolved it will try a number of tiers of relaxing existing versions.
It still wants to avoid changing the versions of currently installed packages if possible, but if that is required then it will do so.
It will in turn first attempt to install without any currently installed package being changed, then will try relaximng the constraint to allow changing the version of indirect dependencies, then to allowing changing the versions of direct dependencies.
This ends up far more intuitive: if there is a compatible set of package versions then they will be found.
Regardless of if new packages are added all at once or one at a time.

### Precompilation

Precompilation has been enhanced a lot.
That is not the compilation that runs the first time a function is used in a session, but rather the stuff that runs the first time a package is loaded in an environment.

For a start, the precompilation cache no longer goes stale every time you swap environments.
This was a massive pain in julia 1.0, especially if you worked on more than one thing at a time.
This was fixed in 1.3 to have multiple caches, for different environments.
It's easy to forget this one, but it is actually one of the biggest usability enhancements since 1.0.

More dramatically, and less easy to overlook, is the parallelism of precompilation added in 1.6.
Precompiling a package requires precompiling all its dependencies first.
This is now done in parallel, and is automatically triggered when you complete Pkg operations.
In contrast, to happening in series the first time a package is loaded.
No more waiting 5 minutes the first time you load an package with a lot of dependencies.
Further the spiffy animated output shows you what is precompiling at a given time; and a progress bar, which makes it feel (even) faster.

<script id="asciicast-a26toW3opklSEtaRAeXzpcW8W" src="https://asciinema.org/a/a26toW3opklSEtaRAeXzpcW8W.js" async></script>

### Improved conflict messages
This is one of my own contributions.
Julia 1.0 conflict messages are a terrifying wall of text.

![Julia 1.0 conflict log]({{site.url}}/Julia-1.0-1.6-changes/julia1.0-conflict.png)
![Julia 1.6 conflict log]({{site.url}}/Julia-1.0-1.6-changes/julia1.6-conflict.png)

The two main changes are the use of colors, and compressing the version number ranges.
No more giant red wall of numbers.


Colors were added to make it easier to see which version numbers are referring to which package.
There is a bit of a problem that it isn't easy to make sure the colors don't get reused, as there are not many in the 16 color list (especially when you skip a few like black, white and error red).
Due to how Pkg constructs its error messages basically every package in the dependency graph gets some message prepared for it, but not displayed, so just assigning them a color in turn gets it to loop around so doesn't reduce change of colors being reused.
There is away to fix that but it is a big change to add structured log messages that are colored only once they are displayed.
We decided after much debate to assign things colors based on the hash of the package name and shortened UUID.
This means things have consistent colors if you fix one and redo it a still have some remaining.
I think this is going to be a subtle improvement on easy of use.
As a cool hack, you can actually change the color list used.
To get the much larger color list I wanted to use originally you can do:
`append!(Pkg.Resolve.CONFLICT_COLORS,  [21:51; 55:119; 124:142; 160:184; 196:220])`


The other change was consecutive lists of version numbers were compressed to continuous ranges.
In 1.6 these ranges are split only if there is a version that exists between them that is not compatible.
So normally just a single range, since compatibility is typically monotonic.
In contrast in 1.0, they were split if there was a potential version that could exist that is not compatible (even if that version doesn't currently exist).
This mean they split every time the right most nonzero was incremented.
For something with a lot of pre-1.0 versions that is a lot of numbers.
I think the new version is much cleaner and easier to read.


## Base and Standard Libraries

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

### `Base.download` now using libcurl
For a very long time the `download` function which retrieves things over HTTP, was implemented with an amazing hack.
It conditionally shelled out to different programs.
On windows it run a mildly scary powershell script.
On Unixen it first tried to use `curl` then if that wasn't installed it tried to use `wget` and then if that wasn't installed it tried to use `fetch`.
It's low-key amazing that this worked as well as it did -- very few complaints.
But as of 1.6 [it now uses libcurl](https://github.com/JuliaLang/julia/pull/37340).
Using libcurl everywhere gives consistency with proxy settings, and protocol support (beyond HTTP) across all platforms.

It also has more extensive API via the new [Downloads.jl](https://github.com/JuliaLang/Downloads.jl) standard library.
It can do things like progress logging, and it can retrieve headers.
I have [tried getting headers via conditional different commandline download functions](https://github.com/oxinabox/DataDeps.jl/pull/22) before, it is low-key nightmare fuel; and I ended up swapping out the HTTP.jl for that.
It wouldn't be too surprising if eventually we see libcurl swapped out for code extracted from HTTP.jl for a pure julia solution.
HTTP.jl works wonderfully to this, but I suspect untangling the client from the server is just a bit annoying right now, particularly as it is still evolving its API.

### A bunch of curried functions
Julia seems to have ended up with a convention of providing curried methods of functions if that would be useful as the first argument for `filter`.
e.g. `filter(isequal(2), [1,2,3,2,1])`, is the same is `filter(x->isequal(x, 2), [1,2,3,2,1]`).
In particular these are boolean comparison like functions:
with two arguments, where the thing being compared against is the second.
Julia 1.0 had `isequal`, `==` and `in`.
Since then we have added:
`isapprox`, `<`,`<=`,`>`, `>=`, `!=`, `startswith`, `endswith`, and `contains`.
(I added the last 3 😁)


Aside: `contains` is argument flipped `occursin`, it was a thing in julia 0.6 but was removed in 1.0 and now has been added back.
We added it back expressly to have the curried form, and to match `startswith` and `endswith`.

### A ton of other new and improved standard library functions:

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
Kind of silly we didn't have that, and had been being me at least since 0.6.

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

`readdir` now accepts a `join=true|false` keyword argument so that it returns paths with the parent dir.
This is good, almost every time I use `readdir` I used it as:
`joinpath.(x, readdir(x))`.
It is slightly cleaner (and faster) to be able to do `readdir(x; join=true)`.
I think for Julia 2.0 we should consider making it the default.
Also added was a `sort` argument, which I don't see the point of so much, since `sort(readdir(x))` seems cleaner than `readdir(x; sort=true)`; and because I rarely rely on processing files in order.


### More "Why didn't it always work that way" than I can count
Since 1.0's release there have been so many small improvements to functions that I didn't even know happened, because I assumed they always worked that way.
Things like `startswith` supporting regex, and (`parse`](https://github.com/JuliaLang/julia/pull/36199) working on `UUID`s.
