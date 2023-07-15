---
title: Top level code in JuliaLang doesn't do what you think it does
layout: default
---


Hiii, it's ya girl. 
She is sleep deprieved because she need to adjust her sleep cycle 12 hours to prepare for JuliaCon 2023 in Boston.
Thus this blog-post is coming to you fresh from the small hours of the morning in Australia, to keep me awake.
Expect this to be more manic than usual.
I am here today to tell you that you are probabl wrong about what top-level code in julialang does.
Though if you understand precompilation well, then you do know that.
This post will explain what is even the point of `__init__`.

<!--more-->

Let's say, I create a package: `Foo.jl`.
(i'm actually doing this as I create this post. You're welcome.)
Normally I would use [PkgTemplates.jl](https://github.com/JuliaCI/PkgTemplates.jl/) for this.
But it's 12:20am and am making a demonstration.

{% highlight julia-repl %}
(@v1.6) pkg> generate Foo
  Generating  project Foo:
    Foo/Project.toml
    Foo/src/Foo.jl
{% endhighlight %}

And lets give `Foo/src/Foo.jl` the following content:
{% highlight julia %}
module Foo

const x = rand(1:100)

end # module
{% endhighlight %}

So we might expect that that package would define `x` to a random value between 1 and 100 every time the package is loaded.
So lets load the package and check the value of `Foo.x` and test that.
{% highlight julia-repl %}
(@v1.6) pkg> activate .
  Activating environment at `~/Foo/Project.toml`

julia> using Foo
[ Info: Precompiling Foo [6e8a2a8c-8738-4114-964a-5c8b3d9db774]

julia> Foo.x
3
{% endhighlight %}

ok ok, valid.
Now let's restart julia and check again

{% highlight julia-repl %}
(@v1.6) pkg> activate .
  Activating environment at `~/Foo/Project.toml`

julia> using Foo

julia> Foo.x
3
{% endhighlight %}

And again:
{% highlight julia-repl %}
(@v1.6) pkg> activate .
  Activating environment at `~/Foo/Project.toml`

julia> using Foo

julia> Foo.x
3
{% endhighlight %}


![GIF from Broklin 99, of main character saying "cool cool cool, now doubt no doubt" anxiously](https://media.tenor.com/ZtToKPR0niwAAAAC/andy-samberg-cool-cool-cool.gif)

So that's kinda weird, the chance of the same number 3 times in a row is literally one in a million.
So something weird is happening.
It's not re-rolling the number when the package is loaded.
_(This is where some people might guess that I forgot to seed the RNG. But that isn't the case. Julia automatically seeds the RNG [using LibUV's `uvrandom` entropy pool source](https://github.com/JuliaLang/julia/blob/d215d914ee388efb0737135d81dcc581e0016f8e/src/sys.c#L795-L805))

Lets make a change to our package.
Let's add a comment about what we have observed.
Editting `Foo/src/Foo.jl` to say
{% highlight julia %}
module Foo

const x = rand(1:100)  # Tests show this always returns 3

end # module
{% endhighlight %}

Ok now lets check it again.

{% highlight julia-repl %}
(@v1.6) pkg> activate .
  Activating environment at `~/Foo/Project.toml`

julia> using Foo
[ Info: Precompiling Foo [6e8a2a8c-8738-4114-964a-5c8b3d9db774]

julia> Foo.x
72
{% endhighlight %}

uh oh.
It changed.
Lets check again.

{% highlight julia-repl%}

(@v1.6) pkg> activate .
  Activating environment at `~/Foo/Project.toml`

julia> using Foo

julia> Foo.x
72
{% endhighlight %}

![GIF from Broklin 99, of main character saying "uncool uncool uncool" with distress](https://media.tenor.com/pH19cVGIYr8AAAAC/uncool-uncool-uncool-jake-peralta.gif)

I am guessing many readers now have gotten the trick to it.
It changes every time the package gets _precompiled_.

So what is going on during precompilation that does this?

Most people are probably well used to precompilation which loads up the package and saves stuff like the parsed functions etc.
People who are a bit more involved will know about using precompilation to actually save the compiled code (especially in Julia 1.9+ where that saves always down to native code) for a particular method.
Maybe you've used [PrecompileTools](https://github.com/JuliaLang/PrecompileTools.jl) to mark things to be precompiled that way.
**but these things are actually just a special case of what precompilation actually dones**.

Precompilation just runs everything, and then saves the state of the julia runtime to disk.
So this does mean that any functions that called get their JIT compiled saved ([PrecompileTools](https://github.com/JuliaLang/PrecompileTools.jl) just provides helpers for a bit more control over this)

Then when ever you load a package, that saved state is loaded up.
The source code at top level in the package is never run again.
When you call a function that code is run, not from file but out of the state that was stored during precompilation.
Which is where `__init__` comes in.

The code in `__init__`, unlike the top-level code of the module, is run whenever the module is loaded.
So let's fix our package.
Editting `Foo/src/Foo.jl` again:

{% highlight julia %}
module Foo

function __init__()
    @eval const x = rand(1:100)
end

end # module
{% endhighlight %}

We use `@eval` as when run executes things in the global scope.
(we can't use `global x = rand(1:100)` since that woudldn't make it `const`).
Is it great to use `@eval` in this way? I will leave that for a future post (kinda what prompted this post in the first place. I wanted to talk about `@eval` but i needed people to understand precompilation first.).
It's kinda moot as this particular use case is so weird it doesn't truely matter.

{% highlight julia-repl %}
(@v1.6) pkg> activate .
  Activating environment at `~/Foo/Project.toml`

julia> using Foo
[ Info: Precompiling Foo [6e8a2a8c-8738-4114-964a-5c8b3d9db774]

julia> Foo.x
85
{% endhighlight %}

and checking that restarting Julia restarts it:
{% highlight julia%}
(@v1.6) pkg> activate .
  Activating environment at `~/Foo/Project.toml`

julia> using Foo

julia> Foo.x
66
{% endhighlight %}

And we are all good.

I hope this post has been illuminating.
It's served it's purpose of keeping me awake.
It's now after 4am, so I should get ready for bed.
