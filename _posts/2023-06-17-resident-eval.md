---
title: Resident Eval, Top level metaprogramming patterns in JuliaLang
layout: default
---

This post brought to you by the same manic "I gotta stay awake to move my body clock to Boston"  as [last night's blog post](../16/top-level-code-in-julia).
But it's even more manic, as I am very much jetlagged now. Expect typos.
And *weird* digressions.
Anyway, topic this time is metaprogramming patterns.
In particular patterns for how to use eval at the top level.

<!--more-->

So `@eval` has a reputation as evil.
But its easy to over-state that.
I would say that there are 4 main stream metaprogramming features in JuliaLang.
 - `@eval` and `eval` which execute an expression at the top level
 - macros, which allow you to define your own DSL as a transform of julia AST to julia AST
 - String macros, which allows you to define your own DSL as a transform of string to julia AST.
 - `@generated` functions which map from type of input to an AST to execute on the input
 - The 5th secret one is `include(::Function, file)` which is like `include(file)` except it takes a function that is AST to AST which gets exectured on every expression parsed out of the file before it is executed.
 - After that we get into ones that are not really userifacing like compiler plugins and IR transforms (A big part of what I actually do for my day job).

And honestly, in terms of utility vs maintenance cost, I would say they go in about that order.
(Generated functions have all these special rules about what you are and aren't allowed to do, and world ages.)

Eval is fine as long as you remember 3 things:
1. It always runs things at global scope (the other two are corollaries of this)
2. Don't use them inside macros -- generate the AST to not need that.
3. Don't call them inside functions. (There are exceptions to this, e.g. it makes a lot of sense for the `Distributed` stdlib to use it for running work.)

So where does this leave us?
_`@eval` is allowed at top-level code_

This is why I wrote [yesterday's blog post](../16/top-level-code-in-julia), I wanted to make sure people understood what happens to top-level code during precompilation/loading.
A loop `@eval`ing different expressions is free at loading time, cos it only run at precompilation time.
Evan the big loop we created as part of the [Nabla.jl](https://github.com/invenia/Nabla.jl) [ChainRules.jl](https://github.com/JuliaDiff/ChainRules.jl/) barely added anything to the load-time and that was defining 5400 methods or so, and used nontrivial logic.

Aside: I have never played a resident evil game. I am a total wuse when it comes to horror and video games are for nerds.
But I just think its a cool pay on words.



## So what kind of things are top level `@eval` useful for?

### Instead of a Union

Sometimes you need to overload a function on a bunch of different types.
Often the best way to write this is with a simple union:
`foo(x::Union{Bar, Qux, Flarg, Zap} = ...`.
However, some times that leads to method ambiguities.
`Union`s are not considered particularly specific by the dispatch system.
Concrete types on the other hand are:
so that can instead be written as:
{% highlight julia %}
for T in (Bar, Qux, Flarg, Zap)
    @eval foo(x::$T) = ...
end
{% endhighlight %}

Defined this way you can be sure your method wins ambiguities.
Is also often the case that you want something like this but that does something a bit different based on the type and so this is extensible to that. Though often that can be handled elegantly handled with dispatch.


### Wrapper types / Delegation pattern

People often talk about the delegation pattern on the [JuliaLang Discourse](https://discourse.julialang.org/search?q=delegation).
It's a part of the whole [Composition-over-inheritance](https://en.wikipedia.org/wiki/Composition_over_inheritance) thing.
The thing people say is 

> I want my object `Foo` to just act like it is actually it's field `x`, except for a couple of methods"

Now you might think that this is a simple feature to add to the languauge.
Or a macro that could be written once, put in a package and then reused for everything.
My conclusion however, after seeing it multiple times, is what people mean by
_"just act like"_ varies a lot and they don't realize it til they go to write it down.
Then they realize it is actually more variable and context dependant they they think.
For example `identity(foo::Foo)` almost certainly should still return `foo` not `foo.x`.
And at least if `Foo` is a number type probably `+(foo::Foo, foo::Foo)` should rewrap the result as a `Foo`.
Etc etc.
There are lots of different cases and it varies per function.
Sometimes its like "Act just like `x` except do this bit of state updating every operation" (tracked types for AD are like this)
So it is hard to write one general purpose macro.
But it is easy to write out the behavior with an `@eval` loop.
For example

{% highlight julia %}
struct Foo<:Number
    x::Float64
end

# these ops just get applied to backing fields
for f in (iseven, isodd)
    @eval $f(foo::Foo) = $f(foo.x)
end

# these ops apply then rewrap
for f in (+, -, *, /)
    @eval $f(a::Foo, b::Foo) = Foo($f(a.x, b.x))
end
{% endhighlight %}

[NamedDims.jl](https://github.com/invenia/NamedDims.jl/blob/cd36392e440b339ae85966646554a7b7f0fc199b/src/functions.jl#L16) is abosolutely loaded with functions being overload in ways like this.
Its a common thing I have done in almost every package defining a wrapper type.

### At least one argument of this type

You often want your type to define the overall behavour if it is present as any of the arguments.
Sometimes this can be accomplished with `VarArgs{Union{MyType, OtherType}}` but that has a few catches.
I think this was most clearly written up in [this issue](https://github.com/JuliaLang/julia/issues/42455) (though that one is now closed as a duplicate I think its clearer)
One case (of many) that you can't do that for is if `OtherType` is a supertype of `MyType`, since then the `Union{MyType, OtherType}` will just collapse into `OtherType` and so you would endup defining your function on the more generic `OtherType` -- often mistakenly monkey-patching over something.

There is a pattern I have used several times which looks as follows:

{% highlight julia %}
for len in 1:7  # generate all combinations up to length 7
    for mask in Iterators.product(ntuple(_->(true, false), len)...)
        any(mask) || continue  # Don't do this if no argument would be a Foo

        
        arg_names = Symbol[]
        sig = Expr[]
        for (ii, is_foo) in enumerate(mask)
            arg_name = Symbol(:x, ii)
            push!(arg_names, arg_name)
            push!(sig, :($arg_name :: $(is_foo ? :Foo : :Number)))
        end
        body = quote
            # define logic here
            foo_bar($(arg_names...))
        end

        
        eval(Expr(:function, Expr(:call, :bar, sig...), body))
    end
end
{% endhighlight %}

So this would generate:
{% highlight julia %}
function bar(x1::Foo)
    foo_bar(x1)
end
function bar(x1::Foo, x2::Foo)
    foo_bar(x1, x2)
end
function bar(x1::Number, x2::Foo)
    foo_bar(x1, x2)
end
function bar(x1::Foo, x2::Number)
    foo_bar(x1, x2)
end
{% endhighlight %}
etc

This technique can be readily extended for more complexity.

For functions that are truly variadic you can't use this approach.
But often you can guess an upper-bound (and you can trivially increase it if you find you need more)

### Conclusion

`@eval` is nothing to fear.
It's a useful technique that I feel almost any serious julialang developer will have a use for on occation.
Conversely, I do not think that's true for knowing how to write macros or generated functions.
The entire half-million line internal codebase at Invenia had only two macros and honestly those two were debatable as to if they wouldn't have been better as functions, if the API could be imagined slightly differently.

This post was actually way less manic that I expected.
And here I am writing it's conclusion at 5:15am, so its got me through to when I needed to stay awaking til.
(I think I used up a lot of my manic energy elsewhere tonight.)


