---
layout: default
title: "Julia-Antipatterns"
tags:
    - julia
    - jupyter-notebook
---
An Antipattern is a common solution to a problem that over-all makes things worse than they could have been.
This blog post aims to highlight a few antipatterns common in Julia code.
I suspect a lot of this is due to baggage brought from other languages, where these are not Antipatterns, but are infact good pattterns.
This post is to clear things up.
<!--more-->

This post will not cover anything in the [Julia Performance Tips](https://docs.julialang.org/en/v1/manual/performance-tips/).

Each section in this will decribe a different antipattern.
It will discuss:
 - Examples, including highlighting this issues
 - What to do instead
 - Reasons people do this


## NotImplemented Exceptions

This shows up in packages defining APIs that others should implement.
Where one wants to declare and document functions that implementors of the API should overload.
In this antipattern, one declares an abstract type, and a function that takes that abstract type as an argument.
Usually, as the the first abstract following something like fashion from Python etc, as taking the object as the first argument.
This function would throw an error saying that the function was not implemented for this type.

The logic being if someone only implements half the API, the user would get this "Helpful" error message.

**Input:**

<div class="jupyter-input jupyter-cell">
```julia
abstract type AbstractModel end

"""
    probability_estimate(model, observation::AbstractArray)::Real

For a given `model`, returns the likelyhood of the `observation` occuring.
"""
function probability_estimate(model::AbstractModel, observation::AbstractArray)
    error("`probability_estimate` has not been implemented for $(typeof(model))")
end


## Now a type implementing this API:
"""
    GuessingModel <: AbstractModel

A model that just guesses. Not even educated guesses. Just random guessing.
"""
struct GuessingModel <: AbstractModel
end

probability_estimate(guesser::GuessingModel, observation::AbstractMatrix) = rand()
```
</div>

**Output:**

<div class="jupyter-cell">


```
probability_estimate (generic function with 2 methods)
```


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
```julia
probability_estimate(GuessingModel(), [1,2,3])
```
</div>

**Output:**


    `probability_estimate` has not been implemented for GuessingModel

    

    Stacktrace:

     [1] error(::String) at ./error.jl:33

     [2] probability_estimate(::GuessingModel, ::Array{Int64,1}) at ./In[1]:9

     [3] top-level scope at In[2]:1


**What happened?**  
It sure looks like `GuessingModel` has implemented a `probability_estimate` method.
The error does not at all help us see what is wrong.
Astute eyed readers will see what is wrong:
`GuessingModel()` was incorrectly implemented to only work for `AbstractMatrix`, but it was called with a `Vector`,
 so it fell back to the generic method for `AbstractModel`.
But that error message what not informative, and if we hit that deep inside a program we would have no idea what is going on, because it doesn't print the types of all the arguments.

### What to do instead?
Just don't implement the thing you don't want to implement.
A `MethodError` indicates this quite well and as shown gives a more informative error message than you will write.

A often missed feature is that you can declare a function without providing any methods.
This is the ideal way to add documentation for a function that you expect to be overloaded.
This is done via `function probability_estimate end`.
As shown. (using `probability_estimate2` to show how it should be done correctly)

**Input:**

<div class="jupyter-input jupyter-cell">
```julia
"""
    probability_estimate2(model, observation::Vector)::Real

For a given `model`, returns the likelyhood of the `observation` occuring.
"""
function probability_estimate2 end

probability_estimate2(guesser::GuessingModel, observation::AbstractMatrix) = rand()
```
</div>

**Output:**

<div class="jupyter-cell">


```
probability_estimate2 (generic function with 1 method)
```


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
```julia
probability_estimate2(GuessingModel(), [1,2,3])
```
</div>

**Output:**


    MethodError: no method matching probability_estimate2(::GuessingModel, ::Array{Int64,1})
    Closest candidates are:
      probability_estimate2(::GuessingModel, !Matched::Array{T,2} where T) at In[9]:8

    

    Stacktrace:

     [1] top-level scope at In[10]:1


### Aside: Test Suites, for interface testing.
Not the topic of this blog post, but as an aside:
When one is in this situtation, defining a interface that another package would implement, one can provide a test-suite for testing it was implemented correctly.
This is a function they can call in their tests to at least check they have the basics right.
This can take the place of a formal interface (which julia doesn't have), in ensuring that a contract is being met.

**Input:**

<div class="jupyter-input jupyter-cell">
```julia
using Test
function model_testsuite(model)
    @testset "Model API Test Suite for $(typeof(model))" begin
        #...
        @testset "probability_estimate" begin
            p = probability_estimate(model, [1,2,3])
            @test p isa Real
            @test 0 <= p <= 1            
        end
        #...
    end
end

model_testsuite(GuessingModel())
```
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
```
probability_estimate: Error During Test at In[11]:5
  Got exception outside of a @test
  `probability_estimate` has not been implemented for GuessingModel
  Stacktrace:
   [1] error(::String) at ./error.jl:33
   [2] probability_estimate(::GuessingModel, ::Array{Int64,1}) at ./In[5]:4
   [3] macro expansion at ./In[11]:6 [inlined]
   [4] macro expansion at /usr/local/src/julia/julia-1.4/usr/share/julia/stdlib/v1.4/Test/src/Test.jl:1113 [inlined]
   [5] macro expansion at ./In[11]:6 [inlined]
   [6] macro expansion at /usr/local/src/julia/julia-1.4/usr/share/julia/stdlib/v1.4/Test/src/Test.jl:1113 [inlined]
   [7] model_testsuite(::GuessingModel) at ./In[11]:5
   [8] top-level scope at In[11]:13
   [9] eval at ./boot.jl:331 [inlined]
   [10] softscope_include_string(::Module, ::String, ::String) at /Users/oxinabox/.julia/packages/SoftGlobalScope/cSbw5/src/SoftGlobalScope.jl:218
   [11] execute_request(::ZMQ.Socket, ::IJulia.Msg) at /Users/oxinabox/.julia/packages/IJulia/yLI42/src/execute_request.jl:67
   [12] #invokelatest#1 at ./essentials.jl:712 [inlined]
   [13] invokelatest at ./essentials.jl:711 [inlined]
   [14] eventloop(::ZMQ.Socket) at /Users/oxinabox/.julia/packages/IJulia/yLI42/src/eventloop.jl:8
   [15] (::IJulia.var"#15#18")() at ./task.jl:358
  
Test Summary:                          | Error  Total
Model API Test Suite for GuessingModel |     1      1
  probability_estimate                 |     1      1

```
</div>


    Some tests did not pass: 0 passed, 0 failed, 1 errored, 0 broken.

    

    Stacktrace:

     [1] finish(::Test.DefaultTestSet) at /usr/local/src/julia/julia-1.4/usr/share/julia/stdlib/v1.4/Test/src/Test.jl:879

     [2] macro expansion at /usr/local/src/julia/julia-1.4/usr/share/julia/stdlib/v1.4/Test/src/Test.jl:1123 [inlined]

     [3] model_testsuite(::GuessingModel) at ./In[11]:5

     [4] top-level scope at In[11]:13


## Use of macros for performance
The primary purpose of macros is not performance, it is to allow syntax tranformations.
For example, `@view xs[4:end]` gets transformed into `view(xs, 4:lastindex(xs))`: this translation of `end` could not be done by a function.




I think this one mostly comes from people who either learnt C in the 90s,
or who were taught C by people who learnt it in the 90s and haven't caught up with current state of compilers.
Back in the 90s the way to make sure a function was inlined was to write a macro instead of a function
So occationally preople propose to do simple functions using macros.
For example this [Stackoverflow Question](https://stackoverflow.com/a/57943397/179081).

Steven G. Johnson gave a keynote on this at [JuliaCon 2019](https://youtu.be/mSgXWpvQEHE?t=578).


The most agregious examples of this is simple numeric manipulation, that takes advantage of nothing known at compile time.


**Input:**

<div class="jupyter-input jupyter-cell">
```julia
using BenchmarkTools
macro area(r)
    return esc(:(2π * ($r)^2))
end
@btime @area(2)
```
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
```
  0.032 ns (0 allocations: 0 bytes)

```
</div>

<div class="jupyter-cell">


```
25.132741228718345
```


</div>

This has no advantage over a simple function.

**Input:**

<div class="jupyter-input jupyter-cell">
```julia
area(r) = 2π * r^2
@btime area(2)
```
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
```
  0.030 ns (0 allocations: 0 bytes)

```
</div>

<div class="jupyter-cell">


```
25.132741228718345
```


</div>

It has several disadvanges in terms of:
 - Familarity and readability: most people have been using julia for a fair while (years even) before they write their first macro.
 - Extensibility: It is very easy to add most dispatches (In our `area` example it is a small refactoring away from taking a `Shape`). For Macros the only things one can dispatch on is AST components: literals, Symbols or expressions.
 - Understandability when used: all functions basically act the same, where as macros can vary a lot, e.g. some arguments might have to be literals, some arguments might replicate function calls if passed in others might not etc. In most cases, as a user I prefer to call a function than a macro.

### With that said sometimes there are exceptions
If something really is very performance critical and one or more of the following applies: 
 - The compiler is failing to constant fold, and you can't make it.
there is considerable information available at parse time(e.g. literals),
that the compiler seems to be failing to take advantage of
then you could try a macro (or a generated function).
But make absolutely sure to benchmark it before and after.

**Input:**

<div class="jupyter-input jupyter-cell">
```julia
compute_poly(x, coeffs) = sum(a * x^(i-1) for (i, a) in enumerate(coeffs))
```
</div>

**Output:**

<div class="jupyter-cell">


```
compute_poly (generic function with 2 methods)
```


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
```julia
compute_poly(x, coeffs) = sum(a * x^(i-1) for (i, a) in enumerate(coeffs))
```
</div>

**Input:**

<div class="jupyter-input jupyter-cell">
```julia
@btime compute_poly(1, (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17))
```
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
```
  49.146 ns (0 allocations: 0 bytes)

```
</div>

<div class="jupyter-cell">


```
153
```


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
```julia
macro compute_poly(x, coeffs_tuple)
    # a*x^i
    Meta.isexpr(coeffs_tuple, :tupel) || ArgumentError("@compute_poly only accepts a tuple literal as second argument")
    coeffs = coeffs_tuple.args
    terms = map(enumerate(coeffs)) do (i, a)
        a = coeffs[i]
        if a isa Number && x isa Number # it is a literal compute at compile time
            a * x ^ (i-1)
        else
            # an expression, so return an expression
            esc(:($a * $x ^ $(i-1)))
        end
    end
    if all(x isa Number for x in terms)
        return sum(terms)
    else
        return Expr(:call, :+, terms...)
    end
end
```
</div>

**Output:**

<div class="jupyter-cell">


```
@compute_poly (macro with 1 method)
```


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
```julia
@btime @compute_poly(1, (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17))
```
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
```
  0.034 ns (0 allocations: 0 bytes)

```
</div>

<div class="jupyter-cell">


```
153
```


</div>

## Use of Dicts to hold collections of variables.

`Dict`s  or hashmaps are a fantastic data structure, with expected O(1) set and get.
However, they are not a tool for all occasions.
I recall my undergrad data structured lecturer saying just that when we got to the last few weeks of the unit and were covering hashmap which has this great time complexity.
As the time, having just spent most of a semester covering various lists and trees etc, I was like _"Of course not, who would do such a thing?"_.
Now, I suspect I know.
I think its mostly people who didn't have the fortune of a formal computer science education (e.g. most scientists and engineers) and/or never thought to benchmark just how large the constant behind that O(1) time is.
But this antipattern is not really concerned with people using `Dict`s rather than some other data structure.
Its about the use of `Dict` rather than `NamedTuple`.

I see a fair bit of use of `Dict{Symbol}` or `Dict{String}`, which is just holding variables because one wants to group them together.
Things like configuration settings, or model hyperparameters.
Until Julia 0.7 `Dict` was arguably the best object in `Base` if one wasn't willing to declare a `struct`.
There are two problems with that.
The introduction of mutable state, and the performance.

Mutable state is bad for a few reasons.
One of the things mainstream languages have imported from functional languages is the preferrence to avoid state where possible.
Firstly, it's hard to reason about, as one needs to remember its state while tracing logic and watch for places where that state could change, which is ok if in the course of a for-loop, but less great if it is a global like most of the settings I mention.
Secondly, its mutable and odds are you don't want it to be mutated, in the first place.
If my model hyper-parameters live in a immutable data structure then I *know* no method mistakenly changes them,
if they are in a `Dict` I have to trust that noone made a mistake and overrode those settings.
Using an immutable data structure avoids that.


Here is example for a `Dict`.
It highlights that while the time taken to get a value is expected O(1), i.e. constant-time,
that constant is not tiny as it needs to compute the `hash`.
`hash` for `Symbol` is fairly fast, for `String` is ia  bit larger.
For more complcated objects it can be quiet large, often larger than `isequal` as designing a good `hash` function is hard.
But the case we see in this antipattern are mostly `Dict{Symbol}` or `Dict{String}`

**Input:**

<div class="jupyter-input jupyter-cell">
```julia
dict = Dict([:a=>1, :b=>2, :c=>3, :d=>4, :e=>5])
@btime $(dict)[:d];
```
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
```
  8.456 ns (0 allocations: 0 bytes)

```
</div>

**Input:**

<div class="jupyter-input jupyter-cell">
```julia
str_dict = Dict(string(k)=> v for (k,v) in dict)  # convert all the keys to strings
@btime $(str_dict)["d"];
```
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
```
  18.077 ns (0 allocations: 0 bytes)

```
</div>

One alternative is [OrderedCollection's](https://github.com/JuliaCollections/OrderedCollections.jl/) `LittleDict`.
This is a naive pair of lists based dictionary, with expected time `O(n)` but with a much lower cost per actual element as it doesn't need to `hash` anything.

**Input:**

<div class="jupyter-input jupyter-cell">
```julia
using OrderedCollections
little_dict = LittleDict(dict)
@btime $(little_dict)[:d];
```
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
```
  4.793 ns (0 allocations: 0 bytes)

```
</div>

It also comes in a immutable form via `freeze` (or by constructing it with `Tuple`s)

**Input:**

<div class="jupyter-input jupyter-cell">
```julia
frozen_little_dict = freeze(LittleDict(dict))
@btime $(frozen_little_dict)[:d];
```
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
```
  4.547 ns (0 allocations: 0 bytes)

```
</div>

But the real winner here is the `NamedTuple`.
Which performs [constant-folding](https://en.wikipedia.org/wiki/Constant_folding) to remove the indexing operation entirely, and just put the result directly into the AST during compilation.

**Input:**

<div class="jupyter-input jupyter-cell">
```julia
named_tuple = (; dict...)  # create a NamedTuple with the same content as the dict
@btime $(named_tuple)[:d];
```
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
```
  0.032 ns (0 allocations: 0 bytes)

```
</div>

If one is thinking _"I have some constants and I want to group them"_ then look no further than the `NamedTuple`.
It is the right answer.
`Dict` is best when you don't know all the keys when you write the code, and/or if values need to be updated.

## Over constraining argument types

Type constraints in Julia are **only** for dispatch.
If you don't have multiple methods for a function, you don't need any type-constraints.
If you must add type-constraints (for dispatch) do so as losely as possible.


### Reasons people do this:
I think this comes from three main places.
The belief it would make the code faster (false), safer (mostly false), or easier to understand (true)
The first two come from different languages which do not act like Julia.
The last point on ease of understanding is absolutely true, but not worth it most of the time.
One other reason I can imagine is misunderstanding [this part of the documentation](https://docs.julialang.org/en/v1/manual/performance-tips/), which applies to `struct` fields, not arguments.
I hope that misunderstanding is not a common reason.

The belief that adding type constraints makes code faster, comes from not understanding how the JIT compiler works.
Julia specializes every function on the types of all arguments.
This means it generates different machine code that is more optimally suited to the particular types.
This includes things like removing branches that can't be met by this type, static dispatches, as well as actually better CPU instructions than a normal dynmaic language might use.
One can see this change by comparing `@code_typed ((x)->2x)(1.0)` vs `@code_typed ((x)->2x)(0x1)`.
Some languages, for example [Cython](https://cython.readthedocs.io/en/latest/src/quickstart/cythonize.html#faster-code-via-static-typing), *do* become much faster with type-annotations, as they do not have a JIT specializing every function when it occurs.
They do their code generation ahead of time so either have to handle all cases (if not specified) or can optimize for a particular (if specified).
In Julia the code generated for a function will be just as fast with or without type constraints.

The belief that adding type constraints makes code safer, comes from the idea of [type-safety](https://en.wikipedia.org/wiki/Type_safety).
A great advantages of statically-typed ahead-of-time compiled languages is the ability at compile time to catch and report programmer errors using the type system and looking for violated constraint.
Julia is not one of these languages, it is not statically typed so reasoning about types can only ever be partial, and Julia is not ahead to time compiled, so any errors could not be reported til the code is executing anyway.
Julia also don't have the formal notion of an interface or contract assert in the first place.
This lack does have a nice advantage in how duck-typing can allow for simpler compositionality -- by assuming it works and implementing only the parts that don't.
See my earlier [post on this](https://white.ucc.asn.au/2020/02/09/whycompositionaljulia.html#multiple-dispatch--duck-typing).
_Errors will be thrown eventually, when you do something unsupported.

The reason one I do think holds some water, is for understandability.
Putting in type-constraints on function arguments makes them easier to understand.
This is true, it is much clear what: `apply_inner(f::Function, c::Vector{<:Vector})` does, vs `apply_inner(f, c)` does.
But we have other tools to make this clear.
For a start better names, e.g. `apply_inner(func, list_of_lists)`.
As well as documentation: we can and should, put a docstring on most functions.
But I do concede sometimes on this, especially when following the norms of a particular code-base.
I will on occation add a type-constraint because I feel like it does clarify things a lot though.

### Examples

There are many examples of this; and the problems it causes.

### Requiring `AbstractVector` when one just needs an iterator

I think this one is common when people feel uncomfortable that nothing has asserted that their input was iterable, since Julia does not have a type to represent being iterable.
But thats not actually a problem as the assertion will occur when you try to iterate it -- no need to pre-empt it.

**Input:**

<div class="jupyter-input jupyter-cell">
```julia
function my_average(xs::AbstractVector)
    len=0
    total = zero(eltype(xs))
    for x in xs
        len+=1
        total += x
    end
    return total/len
end
```
</div>

**Output:**

<div class="jupyter-cell">


```
my_average (generic function with 1 method)
```


</div>

What goes wrong? There are useful iterators that do not subtype `AbstractVector`.
And converting them into `AbstractVector` via `collect(itr)` would allocate unnecessary memory, which we strive to avoid in high performance code.

**Input:**

<div class="jupyter-input jupyter-cell">
```julia
my_average((1, 3, 4))
```
</div>

**Output:**


    MethodError: no method matching my_average(::Tuple{Int64,Int64,Int64})
    Closest candidates are:
      my_average(!Matched::AbstractArray{T,1} where T) at In[6]:2

    

    Stacktrace:

     [1] top-level scope at In[13]:1


**Input:**

<div class="jupyter-input jupyter-cell">
```julia
data = [1, 2, 3, missing, 5, 4, 3, 2, 1]
my_average(skipmissing(data))
```
</div>

**Output:**


    MethodError: no method matching my_average(::Base.SkipMissing{Array{Union{Missing, Int64},1}})
    Closest candidates are:
      my_average(!Matched::AbstractArray{T,1} where T) at In[6]:2

    

    Stacktrace:

     [1] top-level scope at In[9]:2


### Dispatching on  `AbstractVector{<:Real}` rather than `AbstractVector`

*\*old man here, sitting in a rocking chair\**
*Back in my day we didn't have none of this fancy triangular dispatch, and we were just fine.*

But seriously, the ability to dispatch on the the fact that your type parameter was some subtype of an abstract type, was not introduced into the language until Julia 0.6; and before then people got on just fine.
You actually need this very rarely, because if types are used only for dispatch, you must have both
`AbstractVector{<:Real}` and some other alternative like `AbstractVector{<:AbstractString}` or plain `AbstractVector` also being dispatched on.
And its is generally pretty weird to have the need for a different implementation depending on the element type.
(It happens, but you basically need to be implementing performance optimizations)

**Input:**

<div class="jupyter-input jupyter-cell">
```julia
using BenchmarkTools
terrible_norm(x::AbstractVector{<:Real}) = only(reshape(x, 1, :) * x)
```
</div>

**Output:**

<div class="jupyter-cell">


```
terrible_norm (generic function with 1 method)
```


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
```julia
terrible_norm(1:10)
```
</div>

**Output:**

<div class="jupyter-cell">


```
385
```


</div>

The thing that can go wrong here is that there are many kinds of element types that might only hold real numbers, but that do not have that as a type parameter.

For example, the if the data ever contained `missing` values (common in data science),
but you filtered them out somehow, the array will still be typed `Union{Missing, T}`

**Input:**

<div class="jupyter-input jupyter-cell">
```julia
data = [1, 2, 3, missing]
terrible_norm(@view(data[1:3]))
```
</div>

**Output:**


    MethodError: no method matching terrible_norm(::SubArray{Union{Missing, Int64},1,Array{Union{Missing, Int64},1},Tuple{UnitRange{Int64}},true})
    Closest candidates are:
      terrible_norm(!Matched::AbstractArray{#s6,1} where #s6<:Real) at In[36]:2

    

    Stacktrace:

     [1] top-level scope at In[45]:2


Or from source that *could* contrain non-Real values, but that actually doesn't

let
    x = []
    for ii in 1:10
        push!(x, ii)
    end
    
    terrible_norm(x)
end

### Dispatching on  `Function`


**Input:**

<div class="jupyter-input jupyter-cell">
```julia
apply_inner(func::Function, xss) = [[func(x) for x in xs] for xs in xss]
```
</div>

**Output:**

<div class="jupyter-cell">


```
apply_inner (generic function with 1 method)
```


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
```julia
apply_inner(round, [[0.2, 0.9], [1.2, 1.3, 1.6]])
```
</div>

**Output:**

<div class="jupyter-cell">


```
2-element Array{Array{Float64,1},1}:
 [0.0, 1.0]
 [1.0, 1.0, 2.0]
```


</div>

But this doesn't work on callable objects that don't subtype `Function`.
Which include constructors.

**Input:**

<div class="jupyter-input jupyter-cell">
```julia
apply_inner(Float32, [[0.2, 0.9], [1.2, 1.3, 1.6]])
```
</div>

**Output:**


    MethodError: no method matching apply_inner(::Type{Float32}, ::Array{Array{Float64,1},1})
    Closest candidates are:
      apply_inner(!Matched::Function, ::Any) at In[74]:1

    

    Stacktrace:

     [1] top-level scope at In[82]:1


A workaround to that is to use `Base.Callable` which is a `Union{Type, Function}` so does functions and constructors.
However, this will still miss-out on other callable objects, like `DiffEqBase.ODESolution` and `Flux.Chain`.
(As `Base.Callable` is not exported, it is also probably not part of the intended public API of Julia.)

### Others
There are a few others I have seen. I
Generally one should not dispatch on:
 - `DenseArray` it is **not** the complement of sparse array. There are lots of subtypes of `AbstractArray`, most of which are not obviously sparse, nor are they subtypes of `DenseArray`. In particular wrapper array types that can wrap dense or sparse do not subtype it, e.g. `Symmetric`
 - `AbstractFloat`, can almost always be relaxed to `Real`
 - `DataType`: this will excude the type of `Union`s and `UnionAll`s, so use `Type` instead, unless that is the goal.

