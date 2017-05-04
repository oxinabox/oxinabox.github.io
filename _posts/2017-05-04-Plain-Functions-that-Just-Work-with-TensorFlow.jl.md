---
layout: default
title: "Plain Functions that Just Work with TensorFlow.jl"
tags:
    - julia
    - jupyter-notebook
---
Anyone who has been stalking me may know that I have been making a fairly significant number of PR's against [TensorFlow.jl](https://github.com/malmaud/TensorFlow.jl).
One thing I am particularly keen on is [making the interface really Julian](https://github.com/malmaud/TensorFlow.jl/projects/2). Taking advantage of the ability to overload julia's great syntax for matrix indexing and operations.
I will make another post going into those enhancements sometime in the future; and how great julia's ability to overload things is. Probably after [#209](https://github.com/malmaud/TensorFlow.jl/pull/209) is merged.
This post is not directly about those enhancements, but rather about a emergant feature I noticed today.
I wrote some code to run in base julia, but just by changing the types to `Tensors` it now runs inside TensorFlow, and on my GPU (potentially).
<!--more-->




Technically this did require [one little PR](https://github.com/malmaud/TensorFlow.jl/pull/213), but it was just adding in the linking code for operator.


{% highlight julia %}
using TensorFlow
using Base.Test
{% endhighlight %}

I have defined a function to determine the which bin-index a continous value belongs it.
This is useful if one has discretized a continous range of values; as is done in a histogram.
This code lets you know which bin a given input lays within.

It comes from my current research interest in [using machine learning around the language of colors](https://github.com/oxinabox/ColoringNames.jl/).



{% highlight julia %}
"Determine which bin a continous value belongs in"
function find_bin(value, nbins, range_min=0.0, range_max=1.0)
    portion = nbins * (value / (range_max - range_min))

    clamp(round(Int, portion), 1, nbins)
end
{% endhighlight %}




    find_bin




{% highlight julia %}
@testset "Find_bin" begin
    @test find_bin(0.0, 64) == 1
    @test find_bin(1.0, 64) == 64
    @test find_bin(0.5, 64) == 32
    @test find_bin(0.4999, 64) == 32
    @test find_bin(0.5001, 64) == 32

    n_bins = 20
    for ii in 1.0:n_bins
        @test find_bin(ii, 20, 0.0, n_bins) == Int(ii)
    end
    
    @test [10, 11, 19, 2] == find_bin([0.5, 0.51, 0.9, 0.1], 21)
end
{% endhighlight %}

{% highlight plaintext %}
Test Summary: | Pass  Total
  Find_bin    |   26     26

{% endhighlight %}




    Base.Test.DefaultTestSet("Find_bin",Any[],26,false)



It is perfectly nice julia code that runs perfectly happily with the types from `Base`.
Both on scalars, and on `Arrays`, via broadcasting.

Turns out, it will also run perfectly fine on TensorFlow `Tensors`.
This time it will generate an computational graph which can be evaluated.


{% highlight julia %}
sess = Session(Graph())

obs = placeholder(Float32)
bins = find_bin(obs, 100)


{% endhighlight %}

{% highlight plaintext %}
2017-05-04 15:34:12.893787: I tensorflow/core/common_runtime/gpu/gpu_device.cc:887] Found device 0 with properties: 
name: Tesla K40c
major: 3 minor: 5 memoryClockRate (GHz) 0.745
pciBusID 0000:02:00.0
Total memory: 11.17GiB
Free memory: 11.10GiB
2017-05-04 15:34:12.893829: I tensorflow/core/common_runtime/gpu/gpu_device.cc:908] DMA: 0 
2017-05-04 15:34:12.893835: I tensorflow/core/common_runtime/gpu/gpu_device.cc:918] 0:   Y 
2017-05-04 15:34:12.893845: I tensorflow/core/common_runtime/gpu/gpu_device.cc:977] Creating TensorFlow device (/gpu:0) -> (device: 0, name: Tesla K40c, pci bus id: 0000:02:00.0)
WARNING: You are using an old version version of the TensorFlow binary library. It is recommened that you upgrade with Pkg.build("TensorFlow") or various
            errors may be encountered.
 You have 1.0.0 and the new version is 1.0.1.

{% endhighlight %}


{% highlight julia %}
run(sess, bins, Dict(obs=>0.1f0))
{% endhighlight %}




    10




{% highlight julia %}
run(sess, bins, Dict(obs=>[0.1, 0.2, 0.25, 0.261]))
{% endhighlight %}




    4-element Array{Int64,1}:
     10
     20
     25
     26



We can quiet happily run the whole testset from before.
Using `constant` to change the inputs into constant `Tensors`.
then running the operations to get back the result.


{% highlight julia %}
@testset "Find_bin_tensors" begin
    sess = Session(Graph()) #New graph
    
    
    @test run(sess, find_bin(constant(0.0), 64)) == 1
    @test run(sess, find_bin(constant(1.0), 64)) == 64
    @test run(sess, find_bin(constant(0.5), 64)) == 32
    @test run(sess, find_bin(constant(0.4999), 64)) == 32
    @test run(sess, find_bin(constant(0.5001), 64)) == 32

    n_bins = 20
    for ii in 1.0:n_bins
        @test run(sess, find_bin(constant(ii), 20, 0.0, n_bins)) == Int(ii)
    end
    
    @test [10, 11, 19, 2] ==  run(sess, find_bin(constant([0.5, 0.51, 0.9, 0.1]), 21))
end
{% endhighlight %}

{% highlight plaintext %}
Test Summary:    | Pass  
{% endhighlight %}

{% highlight plaintext %}
2017-05-04 15:34:16.021916: I tensorflow/core/common_runtime/gpu/gpu_device.cc:977] Creating TensorFlow device (/gpu:0) -> (device: 0, name: Tesla K40c, pci bus id: 0000:02:00.0)

{% endhighlight %}

{% highlight plaintext %}
Total
  Find_bin_tensors |   26     26

{% endhighlight %}




    Base.Test.DefaultTestSet("Find_bin_tensors",Any[],26,false)



It just works.  
In general that is a great thing to say about any piece of technology.  
Be it a library, a programming language, or a electronic device.

Wether or not it is particular useful to be running integer cliping and rounding operations on the GPU is another question.
It is certainly nice to be able to include this operation as part of a larger network defination.


The really great thing about this, is that the library maker does not need to know anything about TensorFlow, at all.
I certainly didn't have it in mind when I wrote the function.
The function just works on any type, so long as the user provides suitable methods for the functions it uses via multiple dispatch.
This is basically [Duck-Typing](https://en.wikipedia.org/wiki/Duck_typing).
if if it provides methods for `quack` and for `waddle`,
then I can treat it like a `Duck`, even if it is a `Goose`.

It would not work if I had have written say:



{% highlight julia %}
function find_bin_strictly_typed(value::Float64, nbins::Int, range_min::Float64=0.0, range_max::Float64=1.0)
    portion = nbins * (value / (range_max - range_min))

    clamp(round(Int, portion), 1, nbins)
end
{% endhighlight %}




    find_bin_strictly_typed (generic function with 3 methods)




{% highlight julia %}
run(sess, find_bin_strictly_typed(constant(0.4999), 64)) == 32
{% endhighlight %}


    MethodError: no method matching find_bin_strictly_typed(::TensorFlow.Tensor{Float64}, ::Int64)
    Closest candidates are:
      find_bin_strictly_typed(::Float64, ::Int64, ::Float64, ::Float64) at In[8]:2
      find_bin_strictly_typed(::Float64, ::Int64, ::Float64) at In[8]:2
      find_bin_strictly_typed(::Float64, ::Int64) at In[8]:2

    


The moral of the story is *don't over constrain your function parameters*.  
Leave you functions loosely typed, and you may get free functionality later.
