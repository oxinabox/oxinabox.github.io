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
Julia has full support for threading now (as of Julia 1.3).
Not just the limited `@threads for` loops, but full GoLang style threads.
They are tightly integrated with the existing Task/Coroutine system.
In effect threading works by unsetting the sticky flag on a task, so that it is allowed to run on any thread.
This is normally done via the `Threads.@spawn` macro, rather than the `@async` macro.

Interestingly, the `@threads for` macro still remains, and doesn't actually use much of the new machinery. It still uses the old way which is a bit tigher if the loop durations are almost identical.
But the new threading stuff is fast, on the order of microseconds to send work off to another thread.
Even for uses of `@threads for` the improves have some wins.
`IO` is now thread-safe; `ReentrantLock` was added and is the kind of standard lock that you expect to exist, that has notifications on waiting work etc; and a big one: `@threads for` can now be nested without things silently being wrong.


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








