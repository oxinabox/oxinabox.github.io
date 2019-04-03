---
layout: default
title: "Julia Nomenclature"
tags:
    - julia
    - jupyter-notebook
---
These are some terms that get thrown around a lot by julia programmers.
This is a brief writeup of a few of them.

<!--more-->

## Closures

Closures are when a function is created (normally via returning from anotehr function)
that references some variable in the enclosing scope.
We say that it **closes over** those variables.

### Simple

This closure closes over `count`

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
function call_counter()
    count = 0
    return function()
        count+=1
        return count
    end
end
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
call_counter (generic function with 1 method)
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
counter_1 = call_counter()
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
#7 (generic function with 1 method)
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
counter_1()
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
1
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
counter_1()
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
2
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
counter_2 = call_counter()
counter_2()
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
1
{% endhighlight %}


</div>

### Useful

I use this to control early stopping when training neural networks.
This closes over `best_loss` and `remaining_patience`

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
function make_earlystopping(T=Float64; patience=0)
    best_loss::T = typemax(T)
    remaining_patience = patience
    function should_stop!(latest_loss)
        if latest_loss < best_loss
            remaining_patience = patience
            @info "Improved" remaining_patience

            best_loss = latest_loss::T
            return false
        else
            remaining_patience -= 1
            @info "Got worse" remaining_patience
            if remaining_patience < 0
                @info "!!Stopping!!"
                return true
            else
                return false
            end
        end
    end
    return should_stop!
end
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
make_earlystopping (generic function with 2 methods)
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
should_stop! = make_earlystopping(Int; patience=3)
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
should_stop! (generic function with 1 method)
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
should_stop!(99)
should_stop!(97)
should_stop!(100)
should_stop!(100)
should_stop!(101)
should_stop!(102)
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
┌ Info: Improved
│   remaining_patience = 3
└ @ Main In[6]:7
┌ Info: Improved
│   remaining_patience = 3
└ @ Main In[6]:7
┌ Info: Got worse
│   remaining_patience = 2
└ @ Main In[6]:13
┌ Info: Got worse
│   remaining_patience = 1
└ @ Main In[6]:13
┌ Info: Got worse
│   remaining_patience = 0
└ @ Main In[6]:13
┌ Info: Got worse
│   remaining_patience = -1
└ @ Main In[6]:13
┌ Info: !!Stopping!!
└ @ Main In[6]:15

{% endhighlight %}
</div>

<div class="jupyter-cell">


{% highlight plaintext %}
true
{% endhighlight %}


</div>

## you may be using closures without realising it

e.g. the following closes over `model`

```julia

function runall(dates)
    model = Model()
    pmap(dates) do the_day
        simulate(model, the_day) 
    end
end
```

----
# Parallelism

 3 types:
 
  - Multiprocessing / Distributed
  - Multithreading / Shared Memory
  - Asynchronous / Coroutines

## Multiprocessing / Distributed
  - this is `pmap`, `remotecall`, `@spawn`.
  - Actually starts seperate julia process
  - potentially on another machine
  - Often has high communication overhead
  

## Multithreading / Shared Memory
 - this is `@threads`
 - Also in julia 1.2 is coming **PARTR**
 - Can be unsafe, care must always be taken to do things in a threadsafe way

## Asynchronous / Coroutines
 - this is `@async`, and `@asyncmap`
 - Does not actually allow two things to run at once, but allows tasks to take turns running
 - Mostly safe
 - Does not lead to speedup unless the "work" is done elsewhere
     - e.g. in `IO` the time is spent filling network buffers / spinning up disks
     - e.g. if you are spawning extra process like with `run` time is spent in those processes.
 

---

# Dynamic Dispatch vs Static Dispatch

 - If which method to call needs to be dicided at **runtime** then it will be a **dynamic dispatch**
     - i.e. if it nees to be is decided by the **values** of the input, or by **external** factors
 - If it can be decided at **compile time** it will be a **static dispatch**
     - i.e. if it can be decided only by the **types** of the input

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
foo(x::Int) = x
foo(x::Float64) = 2*x
foo(x::Char) = 3*x

function dynamic_dispatch()
    total = 0 
    for ii in 1:1000
        x = rand() > 2.0 ?  1 : 1.0
        total += foo(x)
    end
    total
end
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
dynamic_dispatch (generic function with 1 method)
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
using BenchmarkTools

@btime dynamic_dispatch()

{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
  2.377 μs (0 allocations: 0 bytes)

{% endhighlight %}
</div>

<div class="jupyter-cell">


{% highlight plaintext %}
2000.0
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
function static_dispatch()
    total = 0 
    for ii in 1:1000
        x = rand() > 10 ?  1 : 1.0
        total += foo(1.0)
    end
    total
end


@btime static_dispatch()
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
  1.716 μs (0 allocations: 0 bytes)

{% endhighlight %}
</div>

<div class="jupyter-cell">


{% highlight plaintext %}
2000.0
{% endhighlight %}


</div>

## Type Stability

Closely related to Dynamic vs Static Dispatch

 - If the *return type* can decided at **compile time** then it will be a **type stable**
     - i.e. if the **return type** is decided only by the **types** of the input
 - If the *return type* can't decided until **run time** then it will be a **type unstable**
     - i.e. if the **return type** is decided by the **values** of the input, or by **external** factors
 

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
function type_unstable(x)
    if x < 50.0
        return 1
    else
        return 2.0
    end
end

function demo_type_unstable()
    sum(type_unstable, 1.0:100.0)
end
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
demo_type_unstable (generic function with 1 method)
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
@btime demo_type_unstable();
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
  334.707 ns (0 allocations: 0 bytes)

{% endhighlight %}
</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
function type_stable(x)
    if x < 50.0
        return 1.0
    else
        return 2.0
    end
end

function demo_type_stable()
    sum(type_stable, 1.0:100.0)
end
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
demo_type_stable (generic function with 1 method)
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
@btime demo_type_stable();
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
  235.601 ns (0 allocations: 0 bytes)

{% endhighlight %}
</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
@code_warntype type_unstable(1)
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
Body::Union{Float64, Int64}
1 ─ %1 = (Base.sitofp)(Float64, x)::Float64
│   %2 = (Base.lt_float)(%1, 50.0)::Bool
│   %3 = (Base.eq_float)(%1, 50.0)::Bool
│   %4 = (Base.eq_float)(%1, 9.223372036854776e18)::Bool
│   %5 = (Base.fptosi)(Int64, %1)::Int64
│   %6 = (Base.slt_int)(x, %5)::Bool
│   %7 = (Base.or_int)(%4, %6)::Bool
│   %8 = (Base.and_int)(%3, %7)::Bool
│   %9 = (Base.or_int)(%2, %8)::Bool
└──      goto #3 if not %9
2 ─      return 1
3 ─      return 2.0

{% endhighlight %}
</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
@code_warntype type_stable(1)
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
Body::Float64
1 ─ %1 = (Base.sitofp)(Float64, x)::Float64
│   %2 = (Base.lt_float)(%1, 50.0)::Bool
│   %3 = (Base.eq_float)(%1, 50.0)::Bool
│   %4 = (Base.eq_float)(%1, 9.223372036854776e18)::Bool
│   %5 = (Base.fptosi)(Int64, %1)::Int64
│   %6 = (Base.slt_int)(x, %5)::Bool
│   %7 = (Base.or_int)(%4, %6)::Bool
│   %8 = (Base.and_int)(%3, %7)::Bool
│   %9 = (Base.or_int)(%2, %8)::Bool
└──      goto #3 if not %9
2 ─      return 1.0
3 ─      return 2.0

{% endhighlight %}
</div>

---
# Type Piracy

If your package did not define the
 - **Function** (name); or
 - at least 1 of the argument **types**


You are doing a **type piracy**, and this is a bad thing.  
By doing type piracy you can break code in other models even if they don't import your definitions.


**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
methods(mapreduce)
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
# 4 methods for generic function "mapreduce":
[1] mapreduce(f, op, a::Number) in Base at reduce.jl:324
[2] mapreduce(f, op, itr::Base.SkipMissing{#s623} where #s623<:AbstractArray) in Base at missing.jl:202
[3] mapreduce(f, op, A::AbstractArray; dims, kw...) in Base at reducedim.jl:304
[4] mapreduce(f, op, itr; kw...) in Base at reduce.jl:205
{% endhighlight %}


</div>

### Lets define a new method, to reduce the magnitude first element by the first argument and the second by the second

we are going to call it `mapreduce` because is is kind of mapping this reduction in magnitude.
And because this is a slightly forced example.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
function Base.mapreduce(y1, y2, xs::Array)
    ys = [y1, y2]
    return sign.(xs) .* (abs.(xs) .- abs.(ys))
end
{% endhighlight %}
</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
mapreduce(5, 8, [10, -10])
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
2-element Array{Int64,1}:
  5
 -2
{% endhighlight %}


</div>

### Lets sum some numbers

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
sum([1,2,3])
{% endhighlight %}
</div>

**Output:**


    DimensionMismatch("arrays could not be broadcast to a common size")

    

    Stacktrace:

     [1] _bcs1 at ./broadcast.jl:438 [inlined]

     [2] _bcs at ./broadcast.jl:432 [inlined]

     [3] broadcast_shape at ./broadcast.jl:426 [inlined]

     [4] combine_axes at ./broadcast.jl:421 [inlined]

     [5] _axes at ./broadcast.jl:208 [inlined]

     [6] axes at ./broadcast.jl:206 [inlined]

     [7] combine_axes at ./broadcast.jl:422 [inlined]

     [8] combine_axes at ./broadcast.jl:421 [inlined]

     [9] instantiate at ./broadcast.jl:255 [inlined]

     [10] materialize(::Base.Broadcast.Broadcasted{Base.Broadcast.DefaultArrayStyle{1},Nothing,typeof(*),Tuple{Base.Broadcast.Broadcasted{Base.Broadcast.DefaultArrayStyle{1},Nothing,typeof(sign),Tuple{Array{Int64,1}}},Base.Broadcast.Broadcasted{Base.Broadcast.DefaultArrayStyle{1},Nothing,typeof(-),Tuple{Base.Broadcast.Broadcasted{Base.Broadcast.DefaultArrayStyle{1},Nothing,typeof(abs),Tuple{Array{Int64,1}}},Base.Broadcast.Broadcasted{Base.Broadcast.DefaultArrayStyle{1},Nothing,typeof(abs),Tuple{Array{Function,1}}}}}}}) at ./broadcast.jl:753

     [11] mapreduce(::Function, ::Function, ::Array{Int64,1}) at ./In[19]:3

     [12] _sum at ./reducedim.jl:653 [inlined]

     [13] _sum at ./reducedim.jl:652 [inlined]

     [14] #sum#550 at ./reducedim.jl:648 [inlined]

     [15] sum(::Array{Int64,1}) at ./reducedim.jl:648

     [16] top-level scope at In[21]:1


## Glue Packages

Sometimes to make two packages work together,
you have to make them aware of each others types.

For example to implement

```
convert(::Type(DataFrame), axisarray::AxisArray)
```

 where
 - `convert` is from *Base*
 - `DataFrame` is from *DataFrames.jl*
 - `AxisArray` is from *AxisArrays.jl*

Then the only way to do this without **type piracy** is to do it either *DataFrames.jl* or *AxisArrays.jl*.
But that isn't possible without adding a dependency which isn't great.

So instead we have a **Glue Package**, eg, *DataFrameAxisArrayBuddies.jl*,
that adds this method.
It is piracy but it is fairly safe, since it is adding behavour to types that would normally be a method error as is. **Misdemenor type piracy.**


## Wrapper Types and Delegation Pattern

I would argue that this is a core part of [polymorphism via composition](https://en.wikipedia.org/wiki/Composition_over_inheritance).

In the following example, we construct `SampledVector`,
which is a vector-like type that has fast access to the total so that it can quickly calculate the mean.
It is a **wrapper** of the Vector type,
 and it **delegates** several methods to it.
 
 
 Even though it overloads `Statistics.mean`, and `push!`, `size` and `getindex` from `Base`,
 we do not commit **type piracy**, as we alrways own one of the types -- the `SampleVector`.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
using Statistics

mutable struct SamplesVector{T} <: AbstractVector{T}
    backing::Vector{T}
    total::T
end
SamplesVector(xs) = SamplesVector(xs, +(xs...))  # can't use `sum` as we broke that
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
SamplesVector
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
Statistics.mean(sv::SamplesVector) = sv.total/length(sv.backing)
{% endhighlight %}
</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
function Base.push!(sv::SamplesVector, x)
    sv.total += x
    push!(sv.backing, x)
    return sv
end
{% endhighlight %}
</div>

### delegate `size` and `getindex` 

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
Base.size(sv::SamplesVector) = size(sv.backing)
Base.getindex(sv:: SamplesVector, ii) = getindex(sv.backing, ii)
{% endhighlight %}
</div>

### Demo

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
samples = SamplesVector([1,2,3,4,5,6])
mean(samples)
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
3.5
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
push!(samples,7)
mean(samples)
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
4.0
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
samples[1]
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
1
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
samples[3:end]
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
5-element Array{Int64,1}:
 3
 4
 5
 6
 7
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
push!(samples,7)
mean(samples)
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
4.375
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
samples
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
8-element SamplesVector{Int64}:
 1
 2
 3
 4
 5
 6
 7
 7
{% endhighlight %}


</div>

## Tim Holy Traits
Traits as something that naturally falls out of functions that can be performed on types at compile time,
and on having multiple dispatch.
See [previous post for details.](https://white.ucc.asn.au/2018/10/03/Dispatch,-Traits-and-Metaprogramming-Over-Reflection.html#part-2-aslist-including-using-traits).
