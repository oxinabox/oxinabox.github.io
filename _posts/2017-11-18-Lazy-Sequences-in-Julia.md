---
layout: default
title: "Lazy Sequences in Julia"
tags:
    - julia
    - jupyter-notebook
---
I wanted to talk about using Coroutines for lazy sequences in julia.
Because I am rewriting CorpusLoaders.jl to do so in a nondeprecated way.

This basically corresponds to C# and Python's `yield` return statements.
(Many other languages also have this but I think they are the most well known).


The goal of using lazy sequences  is to be able to iterate though something,
without having to load it all into memory.
Since you are only going to be processing it a single element at a time.
Potentially for some kind of moving average, or for acausal language modelling,
a single window of elements at a time.
Point is, at no point do I ever want to load all 20Gb of wikipedia into my program,
nor all 100Gb of Amazon product reviews.

And I especially do not want to load $\infty$ bytes of every prime number.

<!--more-->

First some definitions.

####  Iterators
An iterable is in essence something can processed sequentially.
The iterator is the tool uses to do this.
Sometimes the terms are uses casually and interchangably.
They exact implementation varies from language to language a surprising amount.
Though the core idea remains the same.

In julia they are define by (perhaps the most formal of all) [informal interfaces](https://docs.julialang.org/en/stable/manual/interfaces/#man-interface-iteration-1).
In short iterators in julia are defined by a `start` function which takes an iterable,
and gives back the initial state for an iterator upon it.
a `next` function that takes an iterable and state and gives back the next value, and a new state,
and a `done` function that takes the same and returns a boolean sayign if there iteratator is complete.

They also have Holy traits to define what eltype they return and how long they are.
Not going to go in to this here, but I will note that specifying the `eltype` is a feature  channels have that the 0.5 producer based code does not.
and that 0.6 generators don't have either right now.

Honestly if you are not familar with iterators the rest of this probably isn't going to make much sense.


#### Coroutines.
Coroutines are the generalisation of Functions (subroutines),
to have have multiple entry and exit points.
In julia they are called Task.
They are most notable for being used in the implementation of `@async` etc.
For our purposes,
they have the ability to yield up control to another coroutine;
and when they get control passed back to them, they resume where they left off.

Its worth noting that they are not threads.
They do not themselves ever cause more than 1 thing to happen at a time on a computer.
Though there are similarities in how they operate.

Coroutines can be uses to implement iterators as we will show below


## Examples

I think this is best explained by examples.
So here are 3.

**Input:**

{% highlight julia %}
using BenchmarkTools
using ResumableFunctions
using MacroTools
{% endhighlight %}

**Output:**

{% highlight plaintext %}
INFO: Recompiling stale cache file /home/wheel/oxinabox/.julia/lib/v0.6/ResumableFunctions.ji for module ResumableFunctions.

{% endhighlight %}

## Fibonacci sequence

We will start, just to explain the concepts with the fibonacci sequence.
We are not going to touch the slow recussive definition (recall that julia does not have tail call recursion).
That is not the point we want to illustrate here.


### Fibonacci Array

To begin with an array based methods.
This of course does not actually satisfy our goal of being an infinite sequence.
You must tell it how many to generate in advance.
As we will see later it is absurdly fast compaired to any of the lazy methods.
It does however use the full amount of RAM it ever needs all the time.
Where as the lazy methods that follow only need at any point a fixed amount of RAM.
This doesn't matter for Fibonacci, as it doesn't use much memory.
It would however matter if you were loading hundreds of gigabytes of machine learning data.

As a side note  fibonacci numbers very quickly overflow an `Int64` long before it can get to the 10_000. but that is ok for out demonstration purposes

**Input:**

{% highlight julia %}
function fib_array(n)
    ret = Vector{Int}(n)
    prev=0
    cur=1
    for ii in 1:n
        @inbounds ret[ii] = cur
        prev, cur = (cur, prev+cur) # nice little avoiding a temp here
    end
    ret
end
{% endhighlight %}

**Output:**




    fib_array (generic function with 1 method)



**Input:**

{% highlight julia %}
@btime collect(Iterators.take(fib_array(10_000), 10_000));
{% endhighlight %}

**Output:**

{% highlight plaintext %}
  139.434 μs
{% endhighlight %}

### Fibonancii Producer Task (deprecated)

Tasks in 0.5 used to have a kind of built in functionality similar to `Channel/put!`.
(They still kind of do at a lower level, but it is no longer exposed as an iterable)
This was depreated in 0.6 at [#19841](https://github.com/JuliaLang/julia/pull/19841),
and is not in 0.7-dev.
Here for reference is what it would look like.

**Input:**

{% highlight julia %}
function fib_task()
    prev=0
    cur=1
    Task() do
        while(true)
            produce(cur)
            prev, cur = (cur, prev+cur) # nice little avoiding a temp here
        end
    end
end
{% endhighlight %}

**Output:**




    fib_task (generic function with 1 method)



It is actually easier to explain than the newer Channels way so I will explain it first.
In the main task there is (will be) an iterator.
When `next` is called on that iterator,
the main task calls `consume`, which yields control to a Task which is running the code in the do block.
When that code hits a `produce` it yields control back to the main iterator Task, returning the value from produce to the `consume` call, which results n `next` returning that value.
When `next` is called again in the main task, it will again call `consume` which will result in the control being yielded back to the generating task, which will continue on from where it left, immediately after the `produce` call.
This is how coroutines are used for generating data.
As they can pause midway through a function return a result and contine after when asked to.


I'm not displaying its timings here as it basically shoots a giant pile of deprecation warnings.
It is about 5 seconds, though some of that slowness might be attributed to the deprecation warnings slowing things down.

### Fibonacci Channel
This is what we are really talking about.
From a pure logic standpoint on can think of this as functioning just like the task.
Where `put!` triggers a yeild to the main iterator task, and `take!` (inside `next`) triggers a yield back down the the generating task.
What is actually happening is similar, but with a buffer involved.


The function passed to a channel runs its own Task until it tries to do a `put!` when the buffer is full.
When that happens it yields control back to the main Task, and "sleeps" the generating task.
Which durng iteration will `take!` an element off the buffer,
which will rewake the Task that wants to put things on the buffer (it `@scheduals` it to act).
But it will not nesciarily get it to run straight away,
the main (iterator) Task does not yield until the buffer is empty and it can't do a `take!`.
(though something else, like IO might triger a yield, but not in this code).

**Input:**

{% highlight julia %}
function fib_ch(buff=1)
    prev=0
    cur=1
    Channel(ctype=Int, csize=buff) do c
        while(true)
            put!(c, cur)
            prev, cur = (cur, prev+cur) # nice little avoiding a temp here
        end
    end
end
{% endhighlight %}

**Output:**




    fib_ch (generic function with 2 methods)



**Input:**

{% highlight julia %}
@btime collect(Iterators.take(fib_ch(1), 10_000));
@btime collect(Iterators.take(fib_ch(10), 10_000));
@btime collect(Iterators.take(fib_ch(256), 10_000));
@btime collect(Iterators.take(fib_ch(10_000), 10_000));
{% endhighlight %}

**Output:**

{% highlight plaintext %}
  34.581 ms (60016 allocations: 1.48 MiB)
  6.640 ms (42037 allocations: 1.20 MiB)
  3.554 ms (40613 allocations: 1.19 MiB)
  5.671 ms (60030 allocations: 1.98 MiB)

{% endhighlight %}

It took me a little time to get my head around what the buffer was (because Task producer didn't use them).
It retrospect is is obvious.
It is a buffer.
The point of the buffer from a practical point of view is that it means that there is less task switching.
Modern CPU speeds work because the CPU is very efficient at running predictable code.
Everything stays in cache, pipelining occurs, maybe even SIMD.
Not to mention doing a task switch itself has an overhead.
So the buffer lets that be avoided, while still avoiding doing all the (potentially infinite) amount of work that would be done in the array case.
   
The trade-off is in how big to make your buffer.
Too small and you do task switching anyway, losing the advantages.
Too large and you end up calculating more outputs than you will consume,
and use a lot of memory at any point in time.

I initially made the mistake of setting the buffer size to `typemax(Int64)`,
which resulted in the code hanging, until I did an interupt with <kbd>Ctrl</kbd> + <kbd>C</kbd>.
Which resulted it in completing normally with no errors.
(because it killed the task, midway through filling the huge buffer, well after the points I needed were enqueued).

For interest below is a plot of the timings with different buffer sizes.

**Input:**

{% highlight julia %}
times=Float64[]
buff_sizes = 2.^(0:15)
for buff in buff_sizes
    time = @belapsed collect(Iterators.take(fib_ch($buff), 10_000));
    push!(times, time)
end

using Plots; gr()
plot(buff_sizes, times.*1000; xscale=:log10, title="Effect of varying channel buffer size for fib_ch", ylabel="time (ms)", xlabel="Buffer Size")
{% endhighlight %}

**Output:**




<?xml version="1.0" encoding="utf-8"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="600" height="400" viewBox="0 0 600 400">
<defs>
  <clipPath id="clip00">
    <rect x="0" y="0" width="600" height="400"/>
  </clipPath>
</defs>
<polygon clip-path="url(#clip3100)" points="
0,400 600,400 600,0 0,0 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip01">
    <rect x="120" y="0" width="421" height="400"/>
  </clipPath>
</defs>
<polygon clip-path="url(#clip3100)" points="
44.6753,360.065 580.315,360.065 580.315,31.4961 44.6753,31.4961 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip02">
    <rect x="44" y="31" width="537" height="330"/>
  </clipPath>
</defs>
<polyline clip-path="url(#clip3102)" style="stroke:#000000; stroke-width:0.5; stroke-opacity:0.1; fill:none" points="
  44.6753,355.137 44.6753,36.4246 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#000000; stroke-width:0.5; stroke-opacity:0.1; fill:none" points="
  163.299,355.137 163.299,36.4246 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#000000; stroke-width:0.5; stroke-opacity:0.1; fill:none" points="
  281.923,355.137 281.923,36.4246 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#000000; stroke-width:0.5; stroke-opacity:0.1; fill:none" points="
  400.547,355.137 400.547,36.4246 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#000000; stroke-width:0.5; stroke-opacity:0.1; fill:none" points="
  519.17,355.137 519.17,36.4246 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#000000; stroke-width:0.5; stroke-opacity:0.1; fill:none" points="
  52.7099,343.647 572.28,343.647 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#000000; stroke-width:0.5; stroke-opacity:0.1; fill:none" points="
  52.7099,288.635 572.28,288.635 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#000000; stroke-width:0.5; stroke-opacity:0.1; fill:none" points="
  52.7099,233.622 572.28,233.622 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#000000; stroke-width:0.5; stroke-opacity:0.1; fill:none" points="
  52.7099,178.609 572.28,178.609 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#000000; stroke-width:0.5; stroke-opacity:0.1; fill:none" points="
  52.7099,123.597 572.28,123.597 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#000000; stroke-width:0.5; stroke-opacity:0.1; fill:none" points="
  52.7099,68.5839 572.28,68.5839 
  "/>
<polyline clip-path="url(#clip3100)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  44.6753,360.065 580.315,360.065 
  "/>
<polyline clip-path="url(#clip3100)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  44.6753,360.065 44.6753,31.4961 
  "/>
<polyline clip-path="url(#clip3100)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  44.6753,360.065 44.6753,355.137 
  "/>
<polyline clip-path="url(#clip3100)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  163.299,360.065 163.299,355.137 
  "/>
<polyline clip-path="url(#clip3100)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  281.923,360.065 281.923,355.137 
  "/>
<polyline clip-path="url(#clip3100)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  400.547,360.065 400.547,355.137 
  "/>
<polyline clip-path="url(#clip3100)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  519.17,360.065 519.17,355.137 
  "/>
<polyline clip-path="url(#clip3100)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  44.6753,343.647 52.7099,343.647 
  "/>
<polyline clip-path="url(#clip3100)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  44.6753,288.635 52.7099,288.635 
  "/>
<polyline clip-path="url(#clip3100)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  44.6753,233.622 52.7099,233.622 
  "/>
<polyline clip-path="url(#clip3100)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  44.6753,178.609 52.7099,178.609 
  "/>
<polyline clip-path="url(#clip3100)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  44.6753,123.597 52.7099,123.597 
  "/>
<polyline clip-path="url(#clip3100)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  44.6753,68.5839 52.7099,68.5839 
  "/>
<g clip-path="url(#clip3100)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 44.6753, 373.865)" x="44.6753" y="373.865">10^0</text>
</g>
<g clip-path="url(#clip3100)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 163.299, 373.865)" x="163.299" y="373.865">10^1</text>
</g>
<g clip-path="url(#clip3100)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 281.923, 373.865)" x="281.923" y="373.865">10^2</text>
</g>
<g clip-path="url(#clip3100)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 400.547, 373.865)" x="400.547" y="373.865">10^3</text>
</g>
<g clip-path="url(#clip3100)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 519.17, 373.865)" x="519.17" y="373.865">10^4</text>
</g>
<g clip-path="url(#clip3100)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 38.6753, 348.147)" x="38.6753" y="348.147">5</text>
</g>
<g clip-path="url(#clip3100)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 38.6753, 293.135)" x="38.6753" y="293.135">10</text>
</g>
<g clip-path="url(#clip3100)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 38.6753, 238.122)" x="38.6753" y="238.122">15</text>
</g>
<g clip-path="url(#clip3100)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 38.6753, 183.109)" x="38.6753" y="183.109">20</text>
</g>
<g clip-path="url(#clip3100)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 38.6753, 128.097)" x="38.6753" y="128.097">25</text>
</g>
<g clip-path="url(#clip3100)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 38.6753, 73.0839)" x="38.6753" y="73.0839">30</text>
</g>
<g clip-path="url(#clip3100)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:21; text-anchor:middle;" transform="rotate(0, 312.495, 18)" x="312.495" y="18">Effect of varying channel buffer size for fib_ch</text>
</g>
<g clip-path="url(#clip3100)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:16; text-anchor:middle;" transform="rotate(0, 312.495, 397.6)" x="312.495" y="397.6">Buffer Size</text>
</g>
<g clip-path="url(#clip3100)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:16; text-anchor:middle;" transform="rotate(-90, 14.4, 195.781)" x="14.4" y="195.781">time (ms)</text>
</g>
<polyline clip-path="url(#clip3102)" style="stroke:#009af9; stroke-width:1; stroke-opacity:1; fill:none" points="
  44.6753,31.4961 80.3846,195.87 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#009af9; stroke-width:1; stroke-opacity:1; fill:none" points="
  80.3846,195.87 116.094,277.906 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#009af9; stroke-width:1; stroke-opacity:1; fill:none" points="
  116.094,277.906 151.803,320.042 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#009af9; stroke-width:1; stroke-opacity:1; fill:none" points="
  151.803,320.042 187.513,340.683 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#009af9; stroke-width:1; stroke-opacity:1; fill:none" points="
  187.513,340.683 223.222,350.887 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#009af9; stroke-width:1; stroke-opacity:1; fill:none" points="
  223.222,350.887 258.931,356.264 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#009af9; stroke-width:1; stroke-opacity:1; fill:none" points="
  258.931,356.264 294.64,359.127 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#009af9; stroke-width:1; stroke-opacity:1; fill:none" points="
  294.64,359.127 330.35,360.065 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#009af9; stroke-width:1; stroke-opacity:1; fill:none" points="
  330.35,360.065 366.059,359.987 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#009af9; stroke-width:1; stroke-opacity:1; fill:none" points="
  366.059,359.987 401.768,359.338 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#009af9; stroke-width:1; stroke-opacity:1; fill:none" points="
  401.768,359.338 437.478,356.509 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#009af9; stroke-width:1; stroke-opacity:1; fill:none" points="
  437.478,356.509 473.187,351.165 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#009af9; stroke-width:1; stroke-opacity:1; fill:none" points="
  473.187,351.165 508.896,341.487 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#009af9; stroke-width:1; stroke-opacity:1; fill:none" points="
  508.896,341.487 544.606,320.657 
  "/>
<polyline clip-path="url(#clip3102)" style="stroke:#009af9; stroke-width:1; stroke-opacity:1; fill:none" points="
  544.606,320.657 580.315,278.387 
  "/>
<polygon clip-path="url(#clip3100)" points="
489.799,82.6161 562.315,82.6161 562.315,52.3761 489.799,52.3761 
  " fill="#ffffff" fill-opacity="1"/>
<polyline clip-path="url(#clip3100)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  489.799,82.6161 562.315,82.6161 562.315,52.3761 489.799,52.3761 489.799,82.6161 
  "/>
<polyline clip-path="url(#clip3100)" style="stroke:#009af9; stroke-width:1; stroke-opacity:1; fill:none" points="
  495.799,67.4961 531.799,67.4961 
  "/>
<g clip-path="url(#clip3100)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 537.799, 71.9961)" x="537.799" y="71.9961">y1</text>
</g>
</svg>




### Fibonacci ResumableFunction
So channels are pretty great.
Easy to write and nice.

One problem is, as you can see compared to arrays they are very slow.
Especially if you have a buffer that is too small or too large.
They also allocate (and then free) a lot of memory.

Enter [ResumableFunctions.jl](https://github.com/BenLauwens/ResumableFunctions.jl).

ResumableFunctions lets you keep the same "coroutines pausing after every output" logical model.
But in implementation, it is actually using macros to rewrite your code into a normal iterator,
with a state machine (in the state) tracking where it is upto.
The result of this is (normally) faster, more memory efficient code.

It uses `@yield` instead of `put!` (or `produce`),
and the whole function has to be wrapped in a `@resumable` macro, which does the rewrite.


**Input:**

{% highlight julia %}
@resumable function fib_rf()
    prev=0
    cur=1
    while(true)
        @yield cur
        prev, cur = (cur, prev+cur) # nice little avoiding a temp here
    end
end
{% endhighlight %}

**Output:**




    fib_rf (generic function with 1 method)



**Input:**

{% highlight julia %}
@btime collect(Iterators.take(fib_rf(), 10_000));
{% endhighlight %}

**Output:**

{% highlight plaintext %}
  989.016 μs (10003 allocations: 412.83 KiB)

{% endhighlight %}

For interest this is what the code it is generating looks like:

**Input:**

{% highlight julia %}
@macroexpand(
        @resumable function fib_rf()
            prev=0
            cur=1
            while(true)
                @yield cur
                prev, cur = (cur, prev+cur)
            end
        end
)|> MacroTools.striplines

{% endhighlight %}

**Output:**




    quote 
        begin 
            mutable struct ##835 <: ResumableFunctions.FiniteStateMachineIterator
                _state::UInt8
                prev::Int64
                cur::Int64
                function ##835(; )::##835
                    fsmi = new()
                    fsmi._state = 0x00
                    fsmi
                end
            end
        end
        function (_fsmi::##835)(_arg::Any=nothing; )::Any
            _fsmi._state == 0x00 && $(Expr(:symbolicgoto, Symbol("#367#_STATE_0")))
            _fsmi._state == 0x01 && $(Expr(:symbolicgoto, Symbol("#366#_STATE_1")))
            error("@resumable function has stopped!")
            $(Expr(:symboliclabel, Symbol("#367#_STATE_0")))
            _fsmi._state = 0xff
            _arg isa Exception && throw(_arg)
            _fsmi.prev = 0
            _fsmi.cur = 1
            while true
                _fsmi._state = 0x01
                return _fsmi.cur
                $(Expr(:symboliclabel, Symbol("#366#_STATE_1")))
                _fsmi._state = 0xff
                _arg isa Exception && throw(_arg)
                (_fsmi.prev, _fsmi.cur) = (_fsmi.cur, _fsmi.prev + _fsmi.cur)
            end
        end
        function fib_rf(; )::##835
            ##835()
        end
    end



Its pretty neat.
those `$(Expr(:symbolicgoto...` are julia's good old fashion `@label` and `@goto` macros (just expanded because macroexpand).
See there is no actual Task switching occuring in the expanded code.


On difference compared to using Channels is that the final element returned from a ResumableFunction is the return value of the resumable function itself.
In the case of infinite series (like `fib`) this doesnn't matter, since there is no late value.
but for finite iterables it does.
and it can make writing the resumable function difficult.
(I'm not sure if it would be possible to modify `@resumable` in order to not do this.
I think it would be nontrivial.)
See [ResumableFunctions.jl/#2](https://github.com/BenLauwens/ResumableFunctions.jl/issues/2).

### Generator Fibonacci

Perhaps the most well known way of creating lazy sequences in julia are generator expressions.
`(foo(x) for x in bar)`.
They can also be written in do block functional form as shown below.

**Input:**

{% highlight julia %}
function fib_gen()
    prev=0
    cur=1
    Base.Generator(Iterators.cycle(true)) do _
        out = cur
        prev, cur = (cur, prev+cur)
        out
    end
end
{% endhighlight %}

**Output:**




    fib_gen (generic function with 1 method)



**Input:**

{% highlight julia %}
@btime collect(Iterators.take(fib_gen(), 10_000));
{% endhighlight %}

**Output:**

{% highlight plaintext %}
  6.339 ms (49983 allocations: 1.30 MiB)

{% endhighlight %}

Generators are not as flexible as the coroutine technieques above.
Because they can only have a single return statement.
They are fine this time, because that is all you need for Fibonacci.
The will not work for out next example though.
(You can do it but it is complicated and I think kinda slow)

## Interleave

Interleave is a iterator operation.
Interleave takes an set of iterables,
and outputs one element from each in turn.
It is basically the transpose of `IterTools.chain`.

It is the basic of the logic programming language [Microkanren](http://webyrd.net/scheme-2013/papers/HemannMuKanren2013.pdf).
It allows the language to have infinite pending parellel checks, but to terminate if any one branch find the answer.
We are not going to implement microkanren today, though some people have made julia implementsions before.
[MuKanren.jl](https://github.com/latticetower/MuKanren.jl), [LilKanren.jl](https://github.com/habemus-papadum/LilKanren.jl) (I've not tried these to see if they currently work. Today is not a day I need a logic programming language.).


**Input:**

{% highlight julia %}
function interleave_ch(xs...)
    states = Base.start.(collect(xs))
    Channel(csize=256, ctype=Union{eltype.(xs)...}) do c       
        while true
            alldone = true
            for ii in eachindex(states)
                if !Base.done(xs[ii], states[ii])
                    alldone=false
                    val, states[ii] = next(xs[ii], states[ii])
                    put!(c, val)
                end
            end
            alldone && break
        end
    end
    
end
{% endhighlight %}

**Input:**

{% highlight julia %}
collect(Iterators.take(interleave_ch(fib_ch(), 100:300:900, 'a':'z'), 20)) |> showcompact
{% endhighlight %}

**Output:**

{% highlight plaintext %}
Union{Char, Int64}[1, 100, 'a', 1, 400, 'b', 2, 700, 'c', 3, 'd', 5, 'e', 8, 'f', 13, 'g', 21, 'h', 34]
{% endhighlight %}

**Input:**

{% highlight julia %}
@btime collect(Iterators.take(interleave_ch(fib_ch(), 100:300:900, 'a':'z'), 20));
{% endhighlight %}

**Output:**

{% highlight plaintext %}
  1.103 ms (2875 allocations: 79.52 KiB)

{% endhighlight %}

**Input:**

{% highlight julia %}
@resumable function interleave_rf(xs...)
    states = Base.start.(collect(xs))
    while true
        alldone = true
        for ii in eachindex(states)
            if !Base.done(xs[ii], states[ii])
                alldone=false
                val, states[ii] = next(xs[ii], states[ii])
                @yield val
            end
        end
        alldone && break
    end
end
{% endhighlight %}

**Output:**




    interleave_rf (generic function with 1 method)



**Input:**

{% highlight julia %}
collect(Iterators.take(interleave_rf(fib_rf(), 100:300:900, 'a':'z'), 20)) |> showcompact
{% endhighlight %}

**Output:**

{% highlight plaintext %}
Any[1, 100, 'a', 1, 400, 'b', 2, 700, 'c', 3, 'd', 5, 'e', 8, 'f', 13, 'g', 21, 'h', 34]
{% endhighlight %}

**Input:**

{% highlight julia %}
@btime collect(Iterators.take(interleave_rf(fib_rf(), 100:300:900, 'a':'z'), 20));
{% endhighlight %}

**Output:**

{% highlight plaintext %}
  215.821 μs (510 allocations: 21.22 KiB)

{% endhighlight %}

Another big win for timing for Resumable functions there (though it doesn't catch the eltype. but to be fair the channel took it as an explict parameter).
One thing to mention with resumable functions is that if they reach the end of the iteration they will include in it the final returned value by the function.
Normally `nothing`.
Eg:

**Input:**

{% highlight julia %}
collect(interleave_rf(1:3, 'a':'c')) |> showcompact
{% endhighlight %}

**Output:**

{% highlight plaintext %}
Any[1, 'a', 2, 'b', 3, 'c', nothing]
{% endhighlight %}

**Input:**

{% highlight julia %}
collect(interleave_ch(1:3, 'a':'c')) |> showcompact
{% endhighlight %}

**Output:**

{% highlight plaintext %}
Union{Char, Int64}[1, 'a', 2, 'b', 3, 'c']
{% endhighlight %}

# Primes

This example is not so good because even the iterator version has to keep all past outputs in memory.
However, I'll show it off here,
because its a kinda neat algorith for finding all primes.

(The array version is also going to be faster, even faster in this case, because one can use the Prime Number Theorem to estimate how many primes are less than the number to check up to, and `sizehint!` the array the to be returned.)

If a number is prime, then no prime (except the number itself), will divide it.
Since if it has a divisor that is nonprime, then that divisor itself, will have a prime divisor that will divide the whole.
So we only need to check primes as candidate divisors.
Further: one does not need to check divisiability by all prior primes in order to check if a number $s$ is prime.
One only needs to check divisibility by the primes less than or equal to $\sqrt{x}$, since if $x=a \times b$, for some $a>\sqrt{x}$ that would imply that $b<\sqrt{x}$, and so its composite nature would have been found when $b$ was checked as a divisor.



### Primes Channel

**Input:**

{% highlight julia %}
function primes_ch()
    known_primes = BigInt[2]
    Channel(csize=256, ctype=BigInt) do c
        x = big"3"
        put!(c, 2) # Output the first prime, as we already put int in the list of known primes
        while true
            for p in known_primes
                if p > sqrt(x)
                    # Must be prime as we have not found any divisor
                    push!(known_primes, x)
                    put!(c, x)
                    break
                end
                if x % p == 0 # p divides
                    # not prime
                    break
                end
            end
            x+=1            
        end
    end
end
{% endhighlight %}

**Output:**




    primes_ch (generic function with 1 method)



**Input:**

{% highlight julia %}
collect(Iterators.take(primes_ch(), 100)) |> showcompact
{% endhighlight %}

**Output:**

{% highlight plaintext %}
BigInt[2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, 223, 227, 229, 233, 239, 241, 251, 257, 263, 269, 271, 277, 281, 283, 293, 307, 311, 313, 317, 331, 337, 347, 349, 353, 359, 367, 373, 379, 383, 389, 397, 401, 409, 419, 421, 431, 433, 439, 443, 449, 457, 461, 463, 467, 479, 487, 491, 499, 503, 509, 521, 523, 541]
{% endhighlight %}

**Input:**

{% highlight julia %}
@btime collect(Iterators.take(primes_ch(), 1000));
{% endhighlight %}

**Output:**

{% highlight plaintext %}
  56.644 ms (354943 allocations: 13.77 MiB)

{% endhighlight %}

### Primes Resumable Function

**Input:**

{% highlight julia %}
@resumable function primes_rf()
    known_primes = BigInt[2]
    x = big"3"
    @yield big"2" # Output the first prime, as we already put int in the list of known primes
    while true
        for p in known_primes
            if p > sqrt(x)
                # Must be prime as we have not found any divisor
                push!(known_primes, x)
                @yield x
                break
            end
            if x % p == 0 # p divides
                # not prime
                break
            end
        end
        x+=1            
    end

end
{% endhighlight %}

**Output:**




    primes_rf (generic function with 1 method)



**Input:**

{% highlight julia %}
@btime collect(Iterators.take(primes_rf(), 1000));
{% endhighlight %}

**Output:**

{% highlight plaintext %}
  107.033 ms (365256 allocations: 13.28 MiB)

{% endhighlight %}

Interestingly, the channel version is 2x as fast as the ResumableFunctions version.
I'm not sure why that is.
Could be cache related.


## Conclusions

These coroutine based sequence generators are pretty great.
They are much more flexible than generator expressions.
They are much less annoying to write than custom iterators.
They let you do things lazily to avoid using all your RAM.

They'll probably get faster in future version of julia.
[ResumableFunctions.jl](ResumableFunctions.jl) is a neat package to keep an eye on.
