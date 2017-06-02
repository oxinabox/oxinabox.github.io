---
layout: default
title: "TensorFlow's SVD is significantly worse than LAPACK's, but still very good"
tags:
    - julia
    - jupyter-notebook
---
TensorFlow's SVD is significantly less accurate than LAPACK's (i.e. julia's and numpy/SciPy's backing library for linear algebra).
But still incredibly accurate, so probably don't panic.
Unless your matrices have very large ($>10^6$) values, then the accuracy difference might be relevant for you (but probably isn't).
However, both LAPACK and TensorFlow are not great then -- LAPACK is still much better.
<!--more-->


TensorFlow.jl recently [gained bindings](https://github.com/malmaud/TensorFlow.jl/pull/240) for the SVD operation.
This came as a result of [@malmaud's](https://github.com/malmaud) great work to automatically [creates bindings](https://github.com/malmaud/TensorFlow.jl/issues/195) for all the ops defined by the TensorFlow backend (It is pretty awesome).
Some may be surprised to find that TensorFlow supports [single value decomposition(SVD)](https://en.wikipedia.org/wiki/Singular_value_decomposition) at all.
After all, isn't it a neural network library?
My response to that, which I have said before and will say again,
is that TensorFlow is (effectively) a linear algebra library with automatic differentiation and GPU support.
And having those features, makes it great for implementing neural networks.
But it has more general functionality that you would every expect.
SVD is one of those features; though I am sure it does have a collection of uses for neural networks -- using it to implement PCA for dimensionality reduction as preprocessing comes to mind.


After I had added the binding, to match julia's return value ordering for `Base.svd`,
I wanted to add a test to make sure it was working correctly.
As there are multiple different correct SVD solutions for a given input $M$ I can't just directly check the returned  $U,S,V$ against those returned by julia's `svd`.
So instead we want to use $U,S,V$ to reconstruct $M$ and test that that reconstruction is close-enough
$$M\approx U\;\mathrm{diagm}(S)\;V'$$
Then what is close enough?  
Being as close as julia's SVD gets makes sense.
But when I tested that, it was failing,
so I thought I would give it some slack: allowing 2 times the error.
But on testing that, it wasn't enough slack and the tests failed, so I gave it more (after checking the results did at least make sense).
I ended up allowing 100 times as much reconstruction error, though this may have been a bit much.
Bases on this, I thought I would investigate closer.

These observations are based on TensorFlow.jl, and Julia, but they really apply to any TensorFlow library,and almost any scientific computing library.
All the language specific TensorFlow libraries delegate their operations to the same C/C++ backend.
Most  scientific computing software delegates their linear algrebra routines to some varient of [LAPACK](https://en.wikipedia.org/wiki/LAPACK); not just julia and SciPy/numpy, but also commerial products like [MatLab](https://au.mathworks.com/company/newsletters/articles/matlab-incorporates-lapack.html), and [Mathematica](https://reference.wolfram.com/language/tutorial/LinearAlgebraMatrixComputations.html).
I'm using TensorFlow.jl and julia because that is what I am most familiar with.


There are of-course a [variety of algorithms and variations to those algoriths](https://en.wikipedia.org/wiki/Singular_value_decomposition#Calculating_the_SVD) for calculating SVD.
It will become obvious that TensorFlow and LAPACK are using different ones.
I'll also point out that there is another implementation in [IterativeSolves.jl](https://en.wikipedia.org/wiki/Singular_value_decomposition#Calculating_the_SVD).
I am not going to go into any detail on the differences -- I am no serious numerical computation linear-algebraist; I go and bug applied mathematicians when I need to know that kind of stuff. 

Here we are just looking at the implementations from the outside.

I am not looking at speed here at all. 
I don't know if TensorFlow is faster or slower than LAPACK.
In general this depends significantly on your system setup, and how TensorFlow was compiled.
It has been [reported that it is hugely faster than numpy's](https://relinklabs.com/tensorflow-vs-numpy), but I've only seen the one report and few details.


If you want to look into TensorFlow's accuracy checks, I am aware some of the tests for it can be found on [their github](https://github.com/tensorflow/tensorflow/blob/master/tensorflow/python/kernel_tests/svd_op_test.py). It is checking 32bit floats with a tolerance of $10^{-5}$ and 64 bit floats with a tolerance of $10^{-14}$, I think that is with sum of errors.

LAPACK tests are [here](http://www.netlib.org/lapack/testing/svd.in). However, LAPACK has its own Domain Specific Language for testing, and I don't speak it at all.

On to our own tests:

**Input:**

{% highlight julia %}
using TensorFlow
using Plots
using DataFrames
{% endhighlight %}

To be clear, since these can change with different LAPACKs, and different TensorFlow releases, this is what I am running on:

**Input:**

{% highlight julia %}
versioninfo()
{% endhighlight %}

**Output:**

{% highlight plaintext %}
Julia Version 0.5.1
Commit 6445c82 (2017-03-05 13:25 UTC)
Platform Info:
  OS: Linux (x86_64-pc-linux-gnu)
  CPU: Intel(R) Xeon(R) CPU           E5520  @ 2.27GHz
  WORD_SIZE: 64
  BLAS: libopenblas (USE64BITINT DYNAMIC_ARCH NO_AFFINITY Nehalem)
  LAPACK: libopenblas64_
  LIBM: libopenlibm
  LLVM: libLLVM-3.7.1 (ORCJIT, nehalem)

{% endhighlight %}

**Input:**

{% highlight julia %}
TensorFlow.tf_version()
{% endhighlight %}

**Output:**




    v"1.0.1"



Also, it is worth looking at these errors in the context of the [machine epsilon](https://en.wikipedia.org/wiki/Machine_epsilon).
Most of these errors are far below that; and so don't matter at all.

**Input:**

{% highlight julia %}
eps(Float32)
{% endhighlight %}

**Output:**




    1.1920929f-7



**Input:**

{% highlight julia %}
eps(Float64)
{% endhighlight %}

**Output:**




    2.220446049250313e-16



First we define a function to conveniently call the TensorFlow SVD, on a julia matrix.
This works by adding a `constant` to the graph.
This leaks memory like crazy, since it adds a new node every time the test is run
but that does not matter for purposes of our test.
(But it probably should have been done with a `placeholder` and a feed dictionary)

**Input:**

{% highlight julia %}
sess=Session(Graph())
svd_tf(m) = run(sess, svd(constant(m)))
{% endhighlight %}

Now we define the reconstruction error,
how we will evaluate it.
We are using squared error:
$$err(M,U,S,V)=\sum{(M-U\;\mathrm{diagm}(S)\;V')^2}$$
We get one error result per matrix per method.
(So not mean squared error, since we want to look at the error distribution).  
Note that the evaluation happened entirely in julia, except for the SVD itself.

The choice of sum of square error here, rather than sum of error, is perhaps not ideal.  
I'm honestly not sure.  
Sum of error would give a much larger result – in fact almost all the errors would be above the machine epsilon.
The few papers I have seen evaluating SVD seem to mostly use sum of squared error; but this is not my field.

**Input:**

{% highlight julia %}
recon_err(m, u,s,v) = sum(abs2, m-u*diagm(s)*v')
recon_err_jl(m) = recon_err(m, svd(m)...)
recon_err_tf(m) = recon_err(m, svd_tf(m)...)
{% endhighlight %}

We define a function to run our trials, and collect the results.
Note that this takes a function `matrix_dist_fun(T, size)` that is used to generate the data.
By changing this function we can change the distribution of values in the trial matricies.

**Input:**

{% highlight julia %}
function generate_data(n_samples, matrix_dist_fun, T, size)
    df = DataFrame(err_jl=T[], err_tf=T[])
    for ii in 1:n_samples
        m = matrix_dist_fun(T, size)
        push!(df, Dict(:err_jl => recon_err_jl(m), :err_tf => recon_err_tf(m)))
    end
    df
end
{% endhighlight %}

Here we define the functions to perform our analytics/visualisation.
I think a histogram showing the distribution of $err_{tf}/err_{jl}$ is informative.
an absolute value histogram would also be informative, but when the values are so low, it become hard to read.
As well the quartile values, that is minimum, Q1, median, Q3, maximum, are informative on the absolute values of the error; since they tell us that that say three quarters of all trials showed error less than the given value.

**Input:**

{% highlight julia %}
function plot_relative_error_hist(df)
    histogram(df[:err_tf]./df[:err_jl];
        xlabel="factor by which Tensorflow error is greater than Julia (LAPACK) error",
        ylabel="number of trials with this error",
        title="Histogram of relative error values for SVD reconstruction"
    )
end
{% endhighlight %}

**Input:**

{% highlight julia %}
function  quartile_summary(df, field)
    q0 = minimum(df[field])
    q1 = quantile(df[field], 0.25)
    q2 = median(df[field])
    q3 = quantile(df[field], 0.75)
    q4 = maximum(df[field])
    print("$field:\t")
    @printf("Q0=%0.2e\t Q1=%0.2e\t Q2=%0.2e\t Q3=%0.2e\t Q4=%0.2e", q0, q1, q2, q3, q4)
    println()
    (q0, q1, q2, q3, q4)
end
{% endhighlight %}

**Input:**

{% highlight julia %}
function display_evaluation_figures(df)
    quartile_summary(df, :err_jl)
    quartile_summary(df, :err_tf)
    plot_relative_error_hist(df)
end
{% endhighlight %}

So now onward to the results.
In the results that follow it can been seen that all the absolute errors (even for maximum/Q4) are well below the machine epsilon for the type evaluated. (But see close to the bottom where this does not hold).
It can be seen that it is very rare for TensorFlow to have a lower error than Julia.
Such results would show up as bar in the histogram at $x<1$.
Of which there are some, but vanishingly few. 

**Input:**

{% highlight julia %}
normal100double = generate_data(1000, randn, Float64, (100,100))
display_evaluation_figures(normal100double)
{% endhighlight %}

**Output:**

{% highlight plaintext %}
err_jl:	Q0=3.99e-26	 Q1=4.84e-26	 Q2=5.33e-26	 Q3=6.22e-26	 Q4=1.27e-25
err_tf:	Q0=7.73e-26	 Q1=1.16e-25	 Q2=1.30e-25	 Q3=1.46e-25	 Q4=5.47e-25

{% endhighlight %}

{% highlight plaintext %}
INFO: binning = auto

{% endhighlight %}




<?xml version="1.0" encoding="utf-8"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="600" height="400" viewBox="0 0 600 400">
<defs>
  <clipPath id="clip00">
    <rect x="0" y="0" width="600" height="400"/>
  </clipPath>
</defs>
<polygon clip-path="url(#clip00)" points="
0,400 600,400 600,0 0,0 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip01">
    <rect x="120" y="0" width="421" height="400"/>
  </clipPath>
</defs>
<polygon clip-path="url(#clip00)" points="
45.8815,369.674 596.063,369.674 596.063,23.3815 45.8815,23.3815 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip02">
    <rect x="45" y="23" width="551" height="347"/>
  </clipPath>
</defs>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  132.231,364.48 132.231,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  250.194,364.48 250.194,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  368.158,364.48 368.158,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  486.121,364.48 486.121,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,369.674 587.81,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,277.892 587.81,277.892 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,186.111 587.81,186.111 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,94.3288 587.81,94.3288 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 596.063,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  132.231,369.674 132.231,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  250.194,369.674 250.194,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  368.158,369.674 368.158,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  486.121,369.674 486.121,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 45.8815,23.3815 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 54.1342,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,277.892 54.1342,277.892 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,186.111 54.1342,186.111 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,94.3288 54.1342,94.3288 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 132.231, 381.674)" x="132.231" y="381.674">2.5</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 250.194, 381.674)" x="250.194" y="381.674">5.0</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 368.158, 381.674)" x="368.158" y="381.674">7.5</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 486.121, 381.674)" x="486.121" y="381.674">10.0</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 374.174)" x="44.6815" y="374.174">0</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 282.392)" x="44.6815" y="282.392">100</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 190.611)" x="44.6815" y="190.611">200</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 98.8288)" x="44.6815" y="98.8288">300</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:21; text-anchor:middle;" transform="rotate(0, 320.972, 18)" x="320.972" y="18">Histogram of relative error values for SVD reconstruction</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:16; text-anchor:middle;" transform="rotate(0, 320.972, 397.6)" x="320.972" y="397.6">factor by which Tensorflow error is greater than Julia (LAPACK) error</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:16; text-anchor:middle;" transform="rotate(-90, 14.4, 196.528)" x="14.4" y="196.528">number of trials with this error</text>
</g>
<polygon clip-path="url(#clip02)" points="
61.4526,317.358 61.4526,369.674 85.0453,369.674 85.0453,317.358 61.4526,317.358 61.4526,317.358 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  61.4526,317.358 61.4526,369.674 85.0453,369.674 85.0453,317.358 61.4526,317.358 
  "/>
<polygon clip-path="url(#clip02)" points="
85.0453,190.7 85.0453,369.674 108.638,369.674 108.638,190.7 85.0453,190.7 85.0453,190.7 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  85.0453,190.7 85.0453,369.674 108.638,369.674 108.638,190.7 85.0453,190.7 
  "/>
<polygon clip-path="url(#clip02)" points="
108.638,54.8626 108.638,369.674 132.231,369.674 132.231,54.8626 108.638,54.8626 108.638,54.8626 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  108.638,54.8626 108.638,369.674 132.231,369.674 132.231,54.8626 108.638,54.8626 
  "/>
<polygon clip-path="url(#clip02)" points="
132.231,137.466 132.231,369.674 155.823,369.674 155.823,137.466 132.231,137.466 132.231,137.466 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  132.231,137.466 132.231,369.674 155.823,369.674 155.823,137.466 132.231,137.466 
  "/>
<polygon clip-path="url(#clip02)" points="
155.823,262.289 155.823,369.674 179.416,369.674 179.416,262.289 155.823,262.289 155.823,262.289 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  155.823,262.289 155.823,369.674 179.416,369.674 179.416,262.289 155.823,262.289 
  "/>
<polygon clip-path="url(#clip02)" points="
179.416,343.057 179.416,369.674 203.009,369.674 203.009,343.057 179.416,343.057 179.416,343.057 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  179.416,343.057 179.416,369.674 203.009,369.674 203.009,343.057 179.416,343.057 
  "/>
<polygon clip-path="url(#clip02)" points="
203.009,365.085 203.009,369.674 226.601,369.674 226.601,365.085 203.009,365.085 203.009,365.085 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  203.009,365.085 203.009,369.674 226.601,369.674 226.601,365.085 203.009,365.085 
  "/>
<polygon clip-path="url(#clip02)" points="
226.601,369.674 226.601,369.674 250.194,369.674 250.194,369.674 226.601,369.674 226.601,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  226.601,369.674 226.601,369.674 250.194,369.674 226.601,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
250.194,369.674 250.194,369.674 273.787,369.674 273.787,369.674 250.194,369.674 250.194,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  250.194,369.674 250.194,369.674 273.787,369.674 250.194,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
273.787,369.674 273.787,369.674 297.38,369.674 297.38,369.674 273.787,369.674 273.787,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  273.787,369.674 273.787,369.674 297.38,369.674 273.787,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
297.38,369.674 297.38,369.674 320.972,369.674 320.972,369.674 297.38,369.674 297.38,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  297.38,369.674 297.38,369.674 320.972,369.674 297.38,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
320.972,369.674 320.972,369.674 344.565,369.674 344.565,369.674 320.972,369.674 320.972,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  320.972,369.674 320.972,369.674 344.565,369.674 320.972,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
344.565,369.674 344.565,369.674 368.158,369.674 368.158,369.674 344.565,369.674 344.565,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  344.565,369.674 344.565,369.674 368.158,369.674 344.565,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
368.158,369.674 368.158,369.674 391.75,369.674 391.75,369.674 368.158,369.674 368.158,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  368.158,369.674 368.158,369.674 391.75,369.674 368.158,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
391.75,369.674 391.75,369.674 415.343,369.674 415.343,369.674 391.75,369.674 391.75,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  391.75,369.674 391.75,369.674 415.343,369.674 391.75,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
415.343,369.674 415.343,369.674 438.936,369.674 438.936,369.674 415.343,369.674 415.343,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  415.343,369.674 415.343,369.674 438.936,369.674 415.343,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
438.936,369.674 438.936,369.674 462.528,369.674 462.528,369.674 438.936,369.674 438.936,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  438.936,369.674 438.936,369.674 462.528,369.674 438.936,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
462.528,369.674 462.528,369.674 486.121,369.674 486.121,369.674 462.528,369.674 462.528,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  462.528,369.674 462.528,369.674 486.121,369.674 462.528,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
486.121,369.674 486.121,369.674 509.714,369.674 509.714,369.674 486.121,369.674 486.121,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  486.121,369.674 486.121,369.674 509.714,369.674 486.121,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
509.714,369.674 509.714,369.674 533.306,369.674 533.306,369.674 509.714,369.674 509.714,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  509.714,369.674 509.714,369.674 533.306,369.674 509.714,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
533.306,369.674 533.306,369.674 556.899,369.674 556.899,369.674 533.306,369.674 533.306,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  533.306,369.674 533.306,369.674 556.899,369.674 533.306,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
556.899,368.756 556.899,369.674 580.492,369.674 580.492,368.756 556.899,368.756 556.899,368.756 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  556.899,368.756 556.899,369.674 580.492,369.674 580.492,368.756 556.899,368.756 
  "/>
<polygon clip-path="url(#clip00)" points="
505.547,74.5015 578.063,74.5015 578.063,44.2615 505.547,44.2615 
  " fill="#ffffff" fill-opacity="1"/>
<polyline clip-path="url(#clip00)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  505.547,74.5015 578.063,74.5015 578.063,44.2615 505.547,44.2615 505.547,74.5015 
  "/>
<polygon clip-path="url(#clip00)" points="
511.547,65.4295 547.547,65.4295 547.547,53.3335 511.547,53.3335 511.547,65.4295 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip00)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  511.547,65.4295 547.547,65.4295 547.547,53.3335 511.547,53.3335 511.547,65.4295 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 553.547, 63.8815)" x="553.547" y="63.8815">y1</text>
</g>
</svg>




**Input:**

{% highlight julia %}
normal100float = generate_data(1000, randn, Float32, (100,100))
display_evaluation_figures(normal100float)
{% endhighlight %}

**Output:**

{% highlight plaintext %}
err_jl:	Q0=9.65e-09	 Q1=1.13e-08	 Q2=1.19e-08	 Q3=1.25e-08	 Q4=1.62e-08
err_tf:	Q0=2.38e-08	 Q1=3.63e-08	 Q2=4.02e-08	 Q3=4.49e-08	 Q4=7.15e-08

{% endhighlight %}

{% highlight plaintext %}
INFO: binning = auto

{% endhighlight %}




<?xml version="1.0" encoding="utf-8"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="600" height="400" viewBox="0 0 600 400">
<defs>
  <clipPath id="clip00">
    <rect x="0" y="0" width="600" height="400"/>
  </clipPath>
</defs>
<polygon clip-path="url(#clip00)" points="
0,400 600,400 600,0 0,0 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip01">
    <rect x="120" y="0" width="421" height="400"/>
  </clipPath>
</defs>
<polygon clip-path="url(#clip00)" points="
45.8815,369.674 596.063,369.674 596.063,23.3815 45.8815,23.3815 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip02">
    <rect x="45" y="23" width="551" height="347"/>
  </clipPath>
</defs>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  106.586,364.48 106.586,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  332.256,364.48 332.256,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  557.925,364.48 557.925,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,369.674 587.81,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,258.825 587.81,258.825 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,147.976 587.81,147.976 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,37.1267 587.81,37.1267 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 596.063,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  106.586,369.674 106.586,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  332.256,369.674 332.256,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  557.925,369.674 557.925,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 45.8815,23.3815 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 54.1342,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,258.825 54.1342,258.825 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,147.976 54.1342,147.976 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,37.1267 54.1342,37.1267 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 106.586, 381.674)" x="106.586" y="381.674">2</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 332.256, 381.674)" x="332.256" y="381.674">4</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 557.925, 381.674)" x="557.925" y="381.674">6</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 374.174)" x="44.6815" y="374.174">0</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 263.325)" x="44.6815" y="263.325">50</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 152.476)" x="44.6815" y="152.476">100</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 41.6267)" x="44.6815" y="41.6267">150</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:21; text-anchor:middle;" transform="rotate(0, 320.972, 18)" x="320.972" y="18">Histogram of relative error values for SVD reconstruction</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:16; text-anchor:middle;" transform="rotate(0, 320.972, 397.6)" x="320.972" y="397.6">factor by which Tensorflow error is greater than Julia (LAPACK) error</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:16; text-anchor:middle;" transform="rotate(-90, 14.4, 196.528)" x="14.4" y="196.528">number of trials with this error</text>
</g>
<polygon clip-path="url(#clip02)" points="
61.4526,367.457 61.4526,369.674 84.0195,369.674 84.0195,367.457 61.4526,367.457 61.4526,367.457 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  61.4526,367.457 61.4526,369.674 84.0195,369.674 84.0195,367.457 61.4526,367.457 
  "/>
<polygon clip-path="url(#clip02)" points="
84.0195,363.023 84.0195,369.674 106.586,369.674 106.586,363.023 84.0195,363.023 84.0195,363.023 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  84.0195,363.023 84.0195,369.674 106.586,369.674 106.586,363.023 84.0195,363.023 
  "/>
<polygon clip-path="url(#clip02)" points="
106.586,356.372 106.586,369.674 129.153,369.674 129.153,356.372 106.586,356.372 106.586,356.372 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  106.586,356.372 106.586,369.674 129.153,369.674 129.153,356.372 106.586,356.372 
  "/>
<polygon clip-path="url(#clip02)" points="
129.153,334.202 129.153,369.674 151.72,369.674 151.72,334.202 129.153,334.202 129.153,334.202 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  129.153,334.202 129.153,369.674 151.72,369.674 151.72,334.202 129.153,334.202 
  "/>
<polygon clip-path="url(#clip02)" points="
151.72,263.259 151.72,369.674 174.287,369.674 174.287,263.259 151.72,263.259 151.72,263.259 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  151.72,263.259 151.72,369.674 174.287,369.674 174.287,263.259 151.72,263.259 
  "/>
<polygon clip-path="url(#clip02)" points="
174.287,207.834 174.287,369.674 196.854,369.674 196.854,207.834 174.287,207.834 174.287,207.834 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  174.287,207.834 174.287,369.674 196.854,369.674 196.854,207.834 174.287,207.834 
  "/>
<polygon clip-path="url(#clip02)" points="
196.854,130.24 196.854,369.674 219.421,369.674 219.421,130.24 196.854,130.24 196.854,130.24 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  196.854,130.24 196.854,369.674 219.421,369.674 219.421,130.24 196.854,130.24 
  "/>
<polygon clip-path="url(#clip02)" points="
219.421,54.8626 219.421,369.674 241.988,369.674 241.988,54.8626 219.421,54.8626 219.421,54.8626 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  219.421,54.8626 219.421,369.674 241.988,369.674 241.988,54.8626 219.421,54.8626 
  "/>
<polygon clip-path="url(#clip02)" points="
241.988,99.2023 241.988,369.674 264.555,369.674 264.555,99.2023 241.988,99.2023 241.988,99.2023 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  241.988,99.2023 241.988,369.674 264.555,369.674 264.555,99.2023 241.988,99.2023 
  "/>
<polygon clip-path="url(#clip02)" points="
264.555,92.5513 264.555,369.674 287.122,369.674 287.122,92.5513 264.555,92.5513 264.555,92.5513 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  264.555,92.5513 264.555,369.674 287.122,369.674 287.122,92.5513 264.555,92.5513 
  "/>
<polygon clip-path="url(#clip02)" points="
287.122,128.023 287.122,369.674 309.689,369.674 309.689,128.023 287.122,128.023 287.122,128.023 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  287.122,128.023 287.122,369.674 309.689,369.674 309.689,128.023 287.122,128.023 
  "/>
<polygon clip-path="url(#clip02)" points="
309.689,190.099 309.689,369.674 332.256,369.674 332.256,190.099 309.689,190.099 309.689,190.099 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  309.689,190.099 309.689,369.674 332.256,369.674 332.256,190.099 309.689,190.099 
  "/>
<polygon clip-path="url(#clip02)" points="
332.256,241.089 332.256,369.674 354.823,369.674 354.823,241.089 332.256,241.089 332.256,241.089 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  332.256,241.089 332.256,369.674 354.823,369.674 354.823,241.089 332.256,241.089 
  "/>
<polygon clip-path="url(#clip02)" points="
354.823,274.344 354.823,369.674 377.39,369.674 377.39,274.344 354.823,274.344 354.823,274.344 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  354.823,274.344 354.823,369.674 377.39,369.674 377.39,274.344 354.823,274.344 
  "/>
<polygon clip-path="url(#clip02)" points="
377.39,318.684 377.39,369.674 399.956,369.674 399.956,318.684 377.39,318.684 377.39,318.684 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  377.39,318.684 377.39,369.674 399.956,369.674 399.956,318.684 377.39,318.684 
  "/>
<polygon clip-path="url(#clip02)" points="
399.956,327.551 399.956,369.674 422.523,369.674 422.523,327.551 399.956,327.551 399.956,327.551 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  399.956,327.551 399.956,369.674 422.523,369.674 422.523,327.551 399.956,327.551 
  "/>
<polygon clip-path="url(#clip02)" points="
422.523,343.07 422.523,369.674 445.09,369.674 445.09,343.07 422.523,343.07 422.523,343.07 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  422.523,343.07 422.523,369.674 445.09,369.674 445.09,343.07 422.523,343.07 
  "/>
<polygon clip-path="url(#clip02)" points="
445.09,351.938 445.09,369.674 467.657,369.674 467.657,351.938 445.09,351.938 445.09,351.938 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  445.09,351.938 445.09,369.674 467.657,369.674 467.657,351.938 445.09,351.938 
  "/>
<polygon clip-path="url(#clip02)" points="
467.657,367.457 467.657,369.674 490.224,369.674 490.224,367.457 467.657,367.457 467.657,367.457 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  467.657,367.457 467.657,369.674 490.224,369.674 490.224,367.457 467.657,367.457 
  "/>
<polygon clip-path="url(#clip02)" points="
490.224,369.674 490.224,369.674 512.791,369.674 512.791,369.674 490.224,369.674 490.224,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  490.224,369.674 490.224,369.674 512.791,369.674 490.224,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
512.791,367.457 512.791,369.674 535.358,369.674 535.358,367.457 512.791,367.457 512.791,367.457 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  512.791,367.457 512.791,369.674 535.358,369.674 535.358,367.457 512.791,367.457 
  "/>
<polygon clip-path="url(#clip02)" points="
535.358,369.674 535.358,369.674 557.925,369.674 557.925,369.674 535.358,369.674 535.358,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  535.358,369.674 535.358,369.674 557.925,369.674 535.358,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
557.925,367.457 557.925,369.674 580.492,369.674 580.492,367.457 557.925,367.457 557.925,367.457 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  557.925,367.457 557.925,369.674 580.492,369.674 580.492,367.457 557.925,367.457 
  "/>
<polygon clip-path="url(#clip00)" points="
505.547,74.5015 578.063,74.5015 578.063,44.2615 505.547,44.2615 
  " fill="#ffffff" fill-opacity="1"/>
<polyline clip-path="url(#clip00)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  505.547,74.5015 578.063,74.5015 578.063,44.2615 505.547,44.2615 505.547,74.5015 
  "/>
<polygon clip-path="url(#clip00)" points="
511.547,65.4295 547.547,65.4295 547.547,53.3335 511.547,53.3335 511.547,65.4295 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip00)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  511.547,65.4295 547.547,65.4295 547.547,53.3335 511.547,53.3335 511.547,65.4295 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 553.547, 63.8815)" x="553.547" y="63.8815">y1</text>
</g>
</svg>




**Input:**

{% highlight julia %}
uniform100double = generate_data(1000, rand, Float64, (100,100))
display_evaluation_figures(uniform100double)
{% endhighlight %}

**Output:**

{% highlight plaintext %}
err_jl:	Q0=4.57e-27	 Q1=6.39e-27	 Q2=7.46e-27	 Q3=8.99e-27	 Q4=2.23e-26
err_tf:	Q0=1.27e-26	 Q1=3.95e-26	 Q2=6.08e-26	 Q3=8.84e-26	 Q4=2.10e-25

{% endhighlight %}

{% highlight plaintext %}
INFO: binning = auto

{% endhighlight %}




<?xml version="1.0" encoding="utf-8"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="600" height="400" viewBox="0 0 600 400">
<defs>
  <clipPath id="clip00">
    <rect x="0" y="0" width="600" height="400"/>
  </clipPath>
</defs>
<polygon clip-path="url(#clip00)" points="
0,400 600,400 600,0 0,0 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip01">
    <rect x="120" y="0" width="421" height="400"/>
  </clipPath>
</defs>
<polygon clip-path="url(#clip00)" points="
45.8815,369.674 596.063,369.674 596.063,23.3815 45.8815,23.3815 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip02">
    <rect x="45" y="23" width="551" height="347"/>
  </clipPath>
</defs>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  222.534,364.48 222.534,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  401.513,364.48 401.513,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  580.492,364.48 580.492,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,369.674 587.81,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,302.693 587.81,302.693 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,235.712 587.81,235.712 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,168.731 587.81,168.731 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,101.749 587.81,101.749 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,34.7683 587.81,34.7683 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 596.063,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  222.534,369.674 222.534,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  401.513,369.674 401.513,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  580.492,369.674 580.492,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 45.8815,23.3815 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 54.1342,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,302.693 54.1342,302.693 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,235.712 54.1342,235.712 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,168.731 54.1342,168.731 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,101.749 54.1342,101.749 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,34.7683 54.1342,34.7683 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 222.534, 381.674)" x="222.534" y="381.674">10</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 401.513, 381.674)" x="401.513" y="381.674">20</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 580.492, 381.674)" x="580.492" y="381.674">30</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 374.174)" x="44.6815" y="374.174">0</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 307.193)" x="44.6815" y="307.193">20</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 240.212)" x="44.6815" y="240.212">40</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 173.231)" x="44.6815" y="173.231">60</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 106.249)" x="44.6815" y="106.249">80</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 39.2683)" x="44.6815" y="39.2683">100</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:21; text-anchor:middle;" transform="rotate(0, 320.972, 18)" x="320.972" y="18">Histogram of relative error values for SVD reconstruction</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:16; text-anchor:middle;" transform="rotate(0, 320.972, 397.6)" x="320.972" y="397.6">factor by which Tensorflow error is greater than Julia (LAPACK) error</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:16; text-anchor:middle;" transform="rotate(-90, 14.4, 196.528)" x="14.4" y="196.528">number of trials with this error</text>
</g>
<polygon clip-path="url(#clip02)" points="
61.4526,299.344 61.4526,369.674 79.3505,369.674 79.3505,299.344 61.4526,299.344 61.4526,299.344 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  61.4526,299.344 61.4526,369.674 79.3505,369.674 79.3505,299.344 61.4526,299.344 
  "/>
<polygon clip-path="url(#clip02)" points="
79.3505,182.127 79.3505,369.674 97.2484,369.674 97.2484,182.127 79.3505,182.127 79.3505,182.127 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  79.3505,182.127 79.3505,369.674 97.2484,369.674 97.2484,182.127 79.3505,182.127 
  "/>
<polygon clip-path="url(#clip02)" points="
97.2484,118.495 97.2484,369.674 115.146,369.674 115.146,118.495 97.2484,118.495 97.2484,118.495 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  97.2484,118.495 97.2484,369.674 115.146,369.674 115.146,118.495 97.2484,118.495 
  "/>
<polygon clip-path="url(#clip02)" points="
115.146,71.6079 115.146,369.674 133.044,369.674 133.044,71.6079 115.146,71.6079 115.146,71.6079 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  115.146,71.6079 115.146,369.674 133.044,369.674 133.044,71.6079 115.146,71.6079 
  "/>
<polygon clip-path="url(#clip02)" points="
133.044,54.8626 133.044,369.674 150.942,369.674 150.942,54.8626 133.044,54.8626 133.044,54.8626 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  133.044,54.8626 133.044,369.674 150.942,369.674 150.942,54.8626 133.044,54.8626 
  "/>
<polygon clip-path="url(#clip02)" points="
150.942,71.6079 150.942,369.674 168.84,369.674 168.84,71.6079 150.942,71.6079 150.942,71.6079 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  150.942,71.6079 150.942,369.674 168.84,369.674 168.84,71.6079 150.942,71.6079 
  "/>
<polygon clip-path="url(#clip02)" points="
168.84,121.844 168.84,369.674 186.738,369.674 186.738,121.844 168.84,121.844 168.84,121.844 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  168.84,121.844 168.84,369.674 186.738,369.674 186.738,121.844 168.84,121.844 
  "/>
<polygon clip-path="url(#clip02)" points="
186.738,85.0041 186.738,369.674 204.636,369.674 204.636,85.0041 186.738,85.0041 186.738,85.0041 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  186.738,85.0041 186.738,369.674 204.636,369.674 204.636,85.0041 186.738,85.0041 
  "/>
<polygon clip-path="url(#clip02)" points="
204.636,185.476 204.636,369.674 222.534,369.674 222.534,185.476 204.636,185.476 204.636,185.476 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  204.636,185.476 204.636,369.674 222.534,369.674 222.534,185.476 204.636,185.476 
  "/>
<polygon clip-path="url(#clip02)" points="
222.534,151.985 222.534,369.674 240.432,369.674 240.432,151.985 222.534,151.985 222.534,151.985 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  222.534,151.985 222.534,369.674 240.432,369.674 240.432,151.985 222.534,151.985 
  "/>
<polygon clip-path="url(#clip02)" points="
240.432,188.825 240.432,369.674 258.33,369.674 258.33,188.825 240.432,188.825 240.432,188.825 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  240.432,188.825 240.432,369.674 258.33,369.674 258.33,188.825 240.432,188.825 
  "/>
<polygon clip-path="url(#clip02)" points="
258.33,205.57 258.33,369.674 276.227,369.674 276.227,205.57 258.33,205.57 258.33,205.57 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  258.33,205.57 258.33,369.674 276.227,369.674 276.227,205.57 258.33,205.57 
  "/>
<polygon clip-path="url(#clip02)" points="
276.227,249.108 276.227,369.674 294.125,369.674 294.125,249.108 276.227,249.108 276.227,249.108 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  276.227,249.108 276.227,369.674 294.125,369.674 294.125,249.108 276.227,249.108 
  "/>
<polygon clip-path="url(#clip02)" points="
294.125,282.599 294.125,369.674 312.023,369.674 312.023,282.599 294.125,282.599 294.125,282.599 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  294.125,282.599 294.125,369.674 312.023,369.674 312.023,282.599 294.125,282.599 
  "/>
<polygon clip-path="url(#clip02)" points="
312.023,306.042 312.023,369.674 329.921,369.674 329.921,306.042 312.023,306.042 312.023,306.042 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  312.023,306.042 312.023,369.674 329.921,369.674 329.921,306.042 312.023,306.042 
  "/>
<polygon clip-path="url(#clip02)" points="
329.921,322.787 329.921,369.674 347.819,369.674 347.819,322.787 329.921,322.787 329.921,322.787 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  329.921,322.787 329.921,369.674 347.819,369.674 347.819,322.787 329.921,322.787 
  "/>
<polygon clip-path="url(#clip02)" points="
347.819,292.646 347.819,369.674 365.717,369.674 365.717,292.646 347.819,292.646 347.819,292.646 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  347.819,292.646 347.819,369.674 365.717,369.674 365.717,292.646 347.819,292.646 
  "/>
<polygon clip-path="url(#clip02)" points="
365.717,319.438 365.717,369.674 383.615,369.674 383.615,319.438 365.717,319.438 365.717,319.438 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  365.717,319.438 365.717,369.674 383.615,369.674 383.615,319.438 365.717,319.438 
  "/>
<polygon clip-path="url(#clip02)" points="
383.615,319.438 383.615,369.674 401.513,369.674 401.513,319.438 383.615,319.438 383.615,319.438 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  383.615,319.438 383.615,369.674 401.513,369.674 401.513,319.438 383.615,319.438 
  "/>
<polygon clip-path="url(#clip02)" points="
401.513,342.882 401.513,369.674 419.411,369.674 419.411,342.882 401.513,342.882 401.513,342.882 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  401.513,342.882 401.513,369.674 419.411,369.674 419.411,342.882 401.513,342.882 
  "/>
<polygon clip-path="url(#clip02)" points="
419.411,329.485 419.411,369.674 437.309,369.674 437.309,329.485 419.411,329.485 419.411,329.485 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  419.411,329.485 419.411,369.674 437.309,369.674 437.309,329.485 419.411,329.485 
  "/>
<polygon clip-path="url(#clip02)" points="
437.309,352.929 437.309,369.674 455.206,369.674 455.206,352.929 437.309,352.929 437.309,352.929 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  437.309,352.929 437.309,369.674 455.206,369.674 455.206,352.929 437.309,352.929 
  "/>
<polygon clip-path="url(#clip02)" points="
455.206,352.929 455.206,369.674 473.104,369.674 473.104,352.929 455.206,352.929 455.206,352.929 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  455.206,352.929 455.206,369.674 473.104,369.674 473.104,352.929 455.206,352.929 
  "/>
<polygon clip-path="url(#clip02)" points="
473.104,349.58 473.104,369.674 491.002,369.674 491.002,349.58 473.104,349.58 473.104,349.58 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  473.104,349.58 473.104,369.674 491.002,369.674 491.002,349.58 473.104,349.58 
  "/>
<polygon clip-path="url(#clip02)" points="
491.002,359.627 491.002,369.674 508.9,369.674 508.9,359.627 491.002,359.627 491.002,359.627 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  491.002,359.627 491.002,369.674 508.9,369.674 508.9,359.627 491.002,359.627 
  "/>
<polygon clip-path="url(#clip02)" points="
508.9,356.278 508.9,369.674 526.798,369.674 526.798,356.278 508.9,356.278 508.9,356.278 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  508.9,356.278 508.9,369.674 526.798,369.674 526.798,356.278 508.9,356.278 
  "/>
<polygon clip-path="url(#clip02)" points="
526.798,369.674 526.798,369.674 544.696,369.674 544.696,369.674 526.798,369.674 526.798,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  526.798,369.674 526.798,369.674 544.696,369.674 526.798,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
544.696,362.976 544.696,369.674 562.594,369.674 562.594,362.976 544.696,362.976 544.696,362.976 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  544.696,362.976 544.696,369.674 562.594,369.674 562.594,362.976 544.696,362.976 
  "/>
<polygon clip-path="url(#clip02)" points="
562.594,366.325 562.594,369.674 580.492,369.674 580.492,366.325 562.594,366.325 562.594,366.325 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  562.594,366.325 562.594,369.674 580.492,369.674 580.492,366.325 562.594,366.325 
  "/>
<polygon clip-path="url(#clip00)" points="
505.547,74.5015 578.063,74.5015 578.063,44.2615 505.547,44.2615 
  " fill="#ffffff" fill-opacity="1"/>
<polyline clip-path="url(#clip00)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  505.547,74.5015 578.063,74.5015 578.063,44.2615 505.547,44.2615 505.547,74.5015 
  "/>
<polygon clip-path="url(#clip00)" points="
511.547,65.4295 547.547,65.4295 547.547,53.3335 511.547,53.3335 511.547,65.4295 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip00)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  511.547,65.4295 547.547,65.4295 547.547,53.3335 511.547,53.3335 511.547,65.4295 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 553.547, 63.8815)" x="553.547" y="63.8815">y1</text>
</g>
</svg>




**Input:**

{% highlight julia %}
uniform100float = generate_data(1000, rand, Float32, (100,100))
display_evaluation_figures(uniform100float)
{% endhighlight %}

**Output:**

{% highlight plaintext %}
err_jl:	Q0=1.07e-09	 Q1=1.31e-09	 Q2=1.47e-09	 Q3=1.69e-09	 Q4=2.95e-09
err_tf:	Q0=2.98e-09	 Q1=4.29e-09	 Q2=4.66e-09	 Q3=5.18e-09	 Q4=7.58e-09

{% endhighlight %}

{% highlight plaintext %}
INFO: binning = auto

{% endhighlight %}




<?xml version="1.0" encoding="utf-8"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="600" height="400" viewBox="0 0 600 400">
<defs>
  <clipPath id="clip00">
    <rect x="0" y="0" width="600" height="400"/>
  </clipPath>
</defs>
<polygon clip-path="url(#clip00)" points="
0,400 600,400 600,0 0,0 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip01">
    <rect x="120" y="0" width="421" height="400"/>
  </clipPath>
</defs>
<polygon clip-path="url(#clip00)" points="
45.8815,369.674 596.063,369.674 596.063,23.3815 45.8815,23.3815 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip02">
    <rect x="45" y="23" width="551" height="347"/>
  </clipPath>
</defs>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  126.333,364.48 126.333,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  342.599,364.48 342.599,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  558.865,364.48 558.865,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,369.674 587.81,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,231.599 587.81,231.599 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,93.5237 587.81,93.5237 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 596.063,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  126.333,369.674 126.333,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  342.599,369.674 342.599,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  558.865,369.674 558.865,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 45.8815,23.3815 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 54.1342,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,231.599 54.1342,231.599 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,93.5237 54.1342,93.5237 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 126.333, 381.674)" x="126.333" y="381.674">2</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 342.599, 381.674)" x="342.599" y="381.674">4</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 558.865, 381.674)" x="558.865" y="381.674">6</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 374.174)" x="44.6815" y="374.174">0</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 236.099)" x="44.6815" y="236.099">50</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 98.0237)" x="44.6815" y="98.0237">100</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:21; text-anchor:middle;" transform="rotate(0, 320.972, 18)" x="320.972" y="18">Histogram of relative error values for SVD reconstruction</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:16; text-anchor:middle;" transform="rotate(0, 320.972, 397.6)" x="320.972" y="397.6">factor by which Tensorflow error is greater than Julia (LAPACK) error</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:16; text-anchor:middle;" transform="rotate(-90, 14.4, 196.528)" x="14.4" y="196.528">number of trials with this error</text>
</g>
<polygon clip-path="url(#clip02)" points="
61.4526,358.628 61.4526,369.674 83.0793,369.674 83.0793,358.628 61.4526,358.628 61.4526,358.628 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  61.4526,358.628 61.4526,369.674 83.0793,369.674 83.0793,358.628 61.4526,358.628 
  "/>
<polygon clip-path="url(#clip02)" points="
83.0793,336.536 83.0793,369.674 104.706,369.674 104.706,336.536 83.0793,336.536 83.0793,336.536 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  83.0793,336.536 83.0793,369.674 104.706,369.674 104.706,336.536 83.0793,336.536 
  "/>
<polygon clip-path="url(#clip02)" points="
104.706,319.967 104.706,369.674 126.333,369.674 126.333,319.967 104.706,319.967 104.706,319.967 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  104.706,319.967 104.706,369.674 126.333,369.674 126.333,319.967 104.706,319.967 
  "/>
<polygon clip-path="url(#clip02)" points="
126.333,253.691 126.333,369.674 147.959,369.674 147.959,253.691 126.333,253.691 126.333,253.691 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  126.333,253.691 126.333,369.674 147.959,369.674 147.959,253.691 126.333,253.691 
  "/>
<polygon clip-path="url(#clip02)" points="
147.959,226.076 147.959,369.674 169.586,369.674 169.586,226.076 147.959,226.076 147.959,226.076 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  147.959,226.076 147.959,369.674 169.586,369.674 169.586,226.076 147.959,226.076 
  "/>
<polygon clip-path="url(#clip02)" points="
169.586,157.038 169.586,369.674 191.212,369.674 191.212,157.038 169.586,157.038 169.586,157.038 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  169.586,157.038 169.586,369.674 191.212,369.674 191.212,157.038 169.586,157.038 
  "/>
<polygon clip-path="url(#clip02)" points="
191.212,93.5237 191.212,369.674 212.839,369.674 212.839,93.5237 191.212,93.5237 191.212,93.5237 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  191.212,93.5237 191.212,369.674 212.839,369.674 212.839,93.5237 191.212,93.5237 
  "/>
<polygon clip-path="url(#clip02)" points="
212.839,99.0467 212.839,369.674 234.466,369.674 234.466,99.0467 212.839,99.0467 212.839,99.0467 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  212.839,99.0467 212.839,369.674 234.466,369.674 234.466,99.0467 212.839,99.0467 
  "/>
<polygon clip-path="url(#clip02)" points="
234.466,88.0007 234.466,369.674 256.092,369.674 256.092,88.0007 234.466,88.0007 234.466,88.0007 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  234.466,88.0007 234.466,369.674 256.092,369.674 256.092,88.0007 234.466,88.0007 
  "/>
<polygon clip-path="url(#clip02)" points="
256.092,54.8626 256.092,369.674 277.719,369.674 277.719,54.8626 256.092,54.8626 256.092,54.8626 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  256.092,54.8626 256.092,369.674 277.719,369.674 277.719,54.8626 256.092,54.8626 
  "/>
<polygon clip-path="url(#clip02)" points="
277.719,88.0007 277.719,369.674 299.346,369.674 299.346,88.0007 277.719,88.0007 277.719,88.0007 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  277.719,88.0007 277.719,369.674 299.346,369.674 299.346,88.0007 277.719,88.0007 
  "/>
<polygon clip-path="url(#clip02)" points="
299.346,148.754 299.346,369.674 320.972,369.674 320.972,148.754 299.346,148.754 299.346,148.754 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  299.346,148.754 299.346,369.674 320.972,369.674 320.972,148.754 299.346,148.754 
  "/>
<polygon clip-path="url(#clip02)" points="
320.972,198.461 320.972,369.674 342.599,369.674 342.599,198.461 320.972,198.461 320.972,198.461 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  320.972,198.461 320.972,369.674 342.599,369.674 342.599,198.461 320.972,198.461 
  "/>
<polygon clip-path="url(#clip02)" points="
342.599,259.214 342.599,369.674 364.225,369.674 364.225,259.214 342.599,259.214 342.599,259.214 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  342.599,259.214 342.599,369.674 364.225,369.674 364.225,259.214 342.599,259.214 
  "/>
<polygon clip-path="url(#clip02)" points="
364.225,278.544 364.225,369.674 385.852,369.674 385.852,278.544 364.225,278.544 364.225,278.544 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  364.225,278.544 364.225,369.674 385.852,369.674 385.852,278.544 364.225,278.544 
  "/>
<polygon clip-path="url(#clip02)" points="
385.852,295.113 385.852,369.674 407.479,369.674 407.479,295.113 385.852,295.113 385.852,295.113 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  385.852,295.113 385.852,369.674 407.479,369.674 407.479,295.113 385.852,295.113 
  "/>
<polygon clip-path="url(#clip02)" points="
407.479,331.013 407.479,369.674 429.105,369.674 429.105,331.013 407.479,331.013 407.479,331.013 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  407.479,331.013 407.479,369.674 429.105,369.674 429.105,331.013 407.479,331.013 
  "/>
<polygon clip-path="url(#clip02)" points="
429.105,336.536 429.105,369.674 450.732,369.674 450.732,336.536 429.105,336.536 429.105,336.536 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  429.105,336.536 429.105,369.674 450.732,369.674 450.732,336.536 429.105,336.536 
  "/>
<polygon clip-path="url(#clip02)" points="
450.732,361.39 450.732,369.674 472.359,369.674 472.359,361.39 450.732,361.39 450.732,361.39 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  450.732,361.39 450.732,369.674 472.359,369.674 472.359,361.39 450.732,361.39 
  "/>
<polygon clip-path="url(#clip02)" points="
472.359,364.151 472.359,369.674 493.985,369.674 493.985,364.151 472.359,364.151 472.359,364.151 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  472.359,364.151 472.359,369.674 493.985,369.674 493.985,364.151 472.359,364.151 
  "/>
<polygon clip-path="url(#clip02)" points="
493.985,364.151 493.985,369.674 515.612,369.674 515.612,364.151 493.985,364.151 493.985,364.151 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  493.985,364.151 493.985,369.674 515.612,369.674 515.612,364.151 493.985,364.151 
  "/>
<polygon clip-path="url(#clip02)" points="
515.612,366.913 515.612,369.674 537.239,369.674 537.239,366.913 515.612,366.913 515.612,366.913 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  515.612,366.913 515.612,369.674 537.239,369.674 537.239,366.913 515.612,366.913 
  "/>
<polygon clip-path="url(#clip02)" points="
537.239,369.674 537.239,369.674 558.865,369.674 558.865,369.674 537.239,369.674 537.239,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  537.239,369.674 537.239,369.674 558.865,369.674 537.239,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
558.865,361.39 558.865,369.674 580.492,369.674 580.492,361.39 558.865,361.39 558.865,361.39 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  558.865,361.39 558.865,369.674 580.492,369.674 580.492,361.39 558.865,361.39 
  "/>
<polygon clip-path="url(#clip00)" points="
505.547,74.5015 578.063,74.5015 578.063,44.2615 505.547,44.2615 
  " fill="#ffffff" fill-opacity="1"/>
<polyline clip-path="url(#clip00)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  505.547,74.5015 578.063,74.5015 578.063,44.2615 505.547,44.2615 505.547,74.5015 
  "/>
<polygon clip-path="url(#clip00)" points="
511.547,65.4295 547.547,65.4295 547.547,53.3335 511.547,53.3335 511.547,65.4295 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip00)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  511.547,65.4295 547.547,65.4295 547.547,53.3335 511.547,53.3335 511.547,65.4295 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 553.547, 63.8815)" x="553.547" y="63.8815">y1</text>
</g>
</svg>




**Input:**

{% highlight julia %}
normal10double = generate_data(1000, randn, Float64, (10,10))
display_evaluation_figures(normal10double)
{% endhighlight %}

**Output:**

{% highlight plaintext %}
err_jl:	Q0=3.69e-29	 Q1=9.58e-29	 Q2=1.38e-28	 Q3=2.24e-28	 Q4=3.18e-27
err_tf:	Q0=1.42e-28	 Q1=4.83e-28	 Q2=7.33e-28	 Q3=1.10e-27	 Q4=5.29e-27

{% endhighlight %}

{% highlight plaintext %}
INFO: binning = auto

{% endhighlight %}




<?xml version="1.0" encoding="utf-8"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="600" height="400" viewBox="0 0 600 400">
<defs>
  <clipPath id="clip00">
    <rect x="0" y="0" width="600" height="400"/>
  </clipPath>
</defs>
<polygon clip-path="url(#clip00)" points="
0,400 600,400 600,0 0,0 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip01">
    <rect x="120" y="0" width="421" height="400"/>
  </clipPath>
</defs>
<polygon clip-path="url(#clip00)" points="
45.8815,369.674 596.063,369.674 596.063,23.3815 45.8815,23.3815 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip02">
    <rect x="45" y="23" width="551" height="347"/>
  </clipPath>
</defs>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  61.4526,364.48 61.4526,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  179.416,364.48 179.416,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  297.38,364.48 297.38,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  415.343,364.48 415.343,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  533.306,364.48 533.306,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,369.674 587.81,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,300.332 587.81,300.332 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,230.991 587.81,230.991 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,161.649 587.81,161.649 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,92.3071 587.81,92.3071 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 596.063,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  61.4526,369.674 61.4526,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  179.416,369.674 179.416,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  297.38,369.674 297.38,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  415.343,369.674 415.343,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  533.306,369.674 533.306,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 45.8815,23.3815 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 54.1342,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,300.332 54.1342,300.332 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,230.991 54.1342,230.991 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,161.649 54.1342,161.649 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,92.3071 54.1342,92.3071 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 61.4526, 381.674)" x="61.4526" y="381.674">0</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 179.416, 381.674)" x="179.416" y="381.674">10</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 297.38, 381.674)" x="297.38" y="381.674">20</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 415.343, 381.674)" x="415.343" y="381.674">30</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 533.306, 381.674)" x="533.306" y="381.674">40</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 374.174)" x="44.6815" y="374.174">0</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 304.832)" x="44.6815" y="304.832">50</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 235.491)" x="44.6815" y="235.491">100</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 166.149)" x="44.6815" y="166.149">150</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 96.8071)" x="44.6815" y="96.8071">200</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:21; text-anchor:middle;" transform="rotate(0, 320.972, 18)" x="320.972" y="18">Histogram of relative error values for SVD reconstruction</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:16; text-anchor:middle;" transform="rotate(0, 320.972, 397.6)" x="320.972" y="397.6">factor by which Tensorflow error is greater than Julia (LAPACK) error</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:16; text-anchor:middle;" transform="rotate(-90, 14.4, 196.528)" x="14.4" y="196.528">number of trials with this error</text>
</g>
<polygon clip-path="url(#clip02)" points="
61.4526,135.299 61.4526,369.674 85.0453,369.674 85.0453,135.299 61.4526,135.299 61.4526,135.299 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  61.4526,135.299 61.4526,369.674 85.0453,369.674 85.0453,135.299 61.4526,135.299 
  "/>
<polygon clip-path="url(#clip02)" points="
85.0453,54.8626 85.0453,369.674 108.638,369.674 108.638,54.8626 85.0453,54.8626 85.0453,54.8626 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  85.0453,54.8626 85.0453,369.674 108.638,369.674 108.638,54.8626 85.0453,54.8626 
  "/>
<polygon clip-path="url(#clip02)" points="
108.638,108.949 108.638,369.674 132.231,369.674 132.231,108.949 108.638,108.949 108.638,108.949 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  108.638,108.949 108.638,369.674 132.231,369.674 132.231,108.949 108.638,108.949 
  "/>
<polygon clip-path="url(#clip02)" points="
132.231,182.451 132.231,369.674 155.823,369.674 155.823,182.451 132.231,182.451 132.231,182.451 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  132.231,182.451 132.231,369.674 155.823,369.674 155.823,182.451 132.231,182.451 
  "/>
<polygon clip-path="url(#clip02)" points="
155.823,258.727 155.823,369.674 179.416,369.674 179.416,258.727 155.823,258.727 155.823,258.727 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  155.823,258.727 155.823,369.674 179.416,369.674 179.416,258.727 155.823,258.727 
  "/>
<polygon clip-path="url(#clip02)" points="
179.416,273.983 179.416,369.674 203.009,369.674 203.009,273.983 179.416,273.983 179.416,273.983 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  179.416,273.983 179.416,369.674 203.009,369.674 203.009,273.983 179.416,273.983 
  "/>
<polygon clip-path="url(#clip02)" points="
203.009,311.427 203.009,369.674 226.601,369.674 226.601,311.427 203.009,311.427 203.009,311.427 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  203.009,311.427 203.009,369.674 226.601,369.674 226.601,311.427 203.009,311.427 
  "/>
<polygon clip-path="url(#clip02)" points="
226.601,335.003 226.601,369.674 250.194,369.674 250.194,335.003 226.601,335.003 226.601,335.003 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  226.601,335.003 226.601,369.674 250.194,369.674 250.194,335.003 226.601,335.003 
  "/>
<polygon clip-path="url(#clip02)" points="
250.194,350.258 250.194,369.674 273.787,369.674 273.787,350.258 250.194,350.258 250.194,350.258 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  250.194,350.258 250.194,369.674 273.787,369.674 273.787,350.258 250.194,350.258 
  "/>
<polygon clip-path="url(#clip02)" points="
273.787,351.645 273.787,369.674 297.38,369.674 297.38,351.645 273.787,351.645 273.787,351.645 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  273.787,351.645 273.787,369.674 297.38,369.674 297.38,351.645 273.787,351.645 
  "/>
<polygon clip-path="url(#clip02)" points="
297.38,354.419 297.38,369.674 320.972,369.674 320.972,354.419 297.38,354.419 297.38,354.419 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  297.38,354.419 297.38,369.674 320.972,369.674 320.972,354.419 297.38,354.419 
  "/>
<polygon clip-path="url(#clip02)" points="
320.972,359.966 320.972,369.674 344.565,369.674 344.565,359.966 320.972,359.966 320.972,359.966 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  320.972,359.966 320.972,369.674 344.565,369.674 344.565,359.966 320.972,359.966 
  "/>
<polygon clip-path="url(#clip02)" points="
344.565,358.579 344.565,369.674 368.158,369.674 368.158,358.579 344.565,358.579 344.565,358.579 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  344.565,358.579 344.565,369.674 368.158,369.674 368.158,358.579 344.565,358.579 
  "/>
<polygon clip-path="url(#clip02)" points="
368.158,365.514 368.158,369.674 391.75,369.674 391.75,365.514 368.158,365.514 368.158,365.514 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  368.158,365.514 368.158,369.674 391.75,369.674 391.75,365.514 368.158,365.514 
  "/>
<polygon clip-path="url(#clip02)" points="
391.75,366.9 391.75,369.674 415.343,369.674 415.343,366.9 391.75,366.9 391.75,366.9 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  391.75,366.9 391.75,369.674 415.343,369.674 415.343,366.9 391.75,366.9 
  "/>
<polygon clip-path="url(#clip02)" points="
415.343,369.674 415.343,369.674 438.936,369.674 438.936,369.674 415.343,369.674 415.343,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  415.343,369.674 415.343,369.674 438.936,369.674 415.343,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
438.936,365.514 438.936,369.674 462.528,369.674 462.528,365.514 438.936,365.514 438.936,365.514 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  438.936,365.514 438.936,369.674 462.528,369.674 462.528,365.514 438.936,365.514 
  "/>
<polygon clip-path="url(#clip02)" points="
462.528,368.287 462.528,369.674 486.121,369.674 486.121,368.287 462.528,368.287 462.528,368.287 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  462.528,368.287 462.528,369.674 486.121,369.674 486.121,368.287 462.528,368.287 
  "/>
<polygon clip-path="url(#clip02)" points="
486.121,368.287 486.121,369.674 509.714,369.674 509.714,368.287 486.121,368.287 486.121,368.287 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  486.121,368.287 486.121,369.674 509.714,369.674 509.714,368.287 486.121,368.287 
  "/>
<polygon clip-path="url(#clip02)" points="
509.714,368.287 509.714,369.674 533.306,369.674 533.306,368.287 509.714,368.287 509.714,368.287 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  509.714,368.287 509.714,369.674 533.306,369.674 533.306,368.287 509.714,368.287 
  "/>
<polygon clip-path="url(#clip02)" points="
533.306,369.674 533.306,369.674 556.899,369.674 556.899,369.674 533.306,369.674 533.306,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  533.306,369.674 533.306,369.674 556.899,369.674 533.306,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
556.899,368.287 556.899,369.674 580.492,369.674 580.492,368.287 556.899,368.287 556.899,368.287 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  556.899,368.287 556.899,369.674 580.492,369.674 580.492,368.287 556.899,368.287 
  "/>
<polygon clip-path="url(#clip00)" points="
505.547,74.5015 578.063,74.5015 578.063,44.2615 505.547,44.2615 
  " fill="#ffffff" fill-opacity="1"/>
<polyline clip-path="url(#clip00)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  505.547,74.5015 578.063,74.5015 578.063,44.2615 505.547,44.2615 505.547,74.5015 
  "/>
<polygon clip-path="url(#clip00)" points="
511.547,65.4295 547.547,65.4295 547.547,53.3335 511.547,53.3335 511.547,65.4295 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip00)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  511.547,65.4295 547.547,65.4295 547.547,53.3335 511.547,53.3335 511.547,65.4295 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 553.547, 63.8815)" x="553.547" y="63.8815">y1</text>
</g>
</svg>




**Input:**

{% highlight julia %}
normal10float = generate_data(1000, randn, Float32, (10,10))
display_evaluation_figures(normal10float)
{% endhighlight %}

**Output:**

{% highlight plaintext %}
err_jl:	Q0=8.95e-12	 Q1=2.14e-11	 Q2=2.80e-11	 Q3=3.74e-11	 Q4=1.11e-10
err_tf:	Q0=3.56e-11	 Q1=1.52e-10	 Q2=2.36e-10	 Q3=3.52e-10	 Q4=1.19e-09

{% endhighlight %}

{% highlight plaintext %}
INFO: binning = auto

{% endhighlight %}




<?xml version="1.0" encoding="utf-8"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="600" height="400" viewBox="0 0 600 400">
<defs>
  <clipPath id="clip00">
    <rect x="0" y="0" width="600" height="400"/>
  </clipPath>
</defs>
<polygon clip-path="url(#clip00)" points="
0,400 600,400 600,0 0,0 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip01">
    <rect x="120" y="0" width="421" height="400"/>
  </clipPath>
</defs>
<polygon clip-path="url(#clip00)" points="
45.8815,369.674 596.063,369.674 596.063,23.3815 45.8815,23.3815 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip02">
    <rect x="45" y="23" width="551" height="347"/>
  </clipPath>
</defs>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  61.4526,364.48 61.4526,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  264.202,364.48 264.202,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  466.952,364.48 466.952,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,369.674 587.81,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,271.296 587.81,271.296 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,172.917 587.81,172.917 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,74.5383 587.81,74.5383 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 596.063,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  61.4526,369.674 61.4526,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  264.202,369.674 264.202,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  466.952,369.674 466.952,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 45.8815,23.3815 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 54.1342,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,271.296 54.1342,271.296 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,172.917 54.1342,172.917 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,74.5383 54.1342,74.5383 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 61.4526, 381.674)" x="61.4526" y="381.674">0</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 264.202, 381.674)" x="264.202" y="381.674">25</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 466.952, 381.674)" x="466.952" y="381.674">50</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 374.174)" x="44.6815" y="374.174">0</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 275.796)" x="44.6815" y="275.796">50</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 177.417)" x="44.6815" y="177.417">100</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 79.0383)" x="44.6815" y="79.0383">150</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:21; text-anchor:middle;" transform="rotate(0, 320.972, 18)" x="320.972" y="18">Histogram of relative error values for SVD reconstruction</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:16; text-anchor:middle;" transform="rotate(0, 320.972, 397.6)" x="320.972" y="397.6">factor by which Tensorflow error is greater than Julia (LAPACK) error</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:16; text-anchor:middle;" transform="rotate(-90, 14.4, 196.528)" x="14.4" y="196.528">number of trials with this error</text>
</g>
<polygon clip-path="url(#clip02)" points="
61.4526,330.323 61.4526,369.674 77.6726,369.674 77.6726,330.323 61.4526,330.323 61.4526,330.323 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  61.4526,330.323 61.4526,369.674 77.6726,369.674 77.6726,330.323 61.4526,330.323 
  "/>
<polygon clip-path="url(#clip02)" points="
77.6726,72.5707 77.6726,369.674 93.8926,369.674 93.8926,72.5707 77.6726,72.5707 77.6726,72.5707 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  77.6726,72.5707 77.6726,369.674 93.8926,369.674 93.8926,72.5707 77.6726,72.5707 
  "/>
<polygon clip-path="url(#clip02)" points="
93.8926,54.8626 93.8926,369.674 110.113,369.674 110.113,54.8626 93.8926,54.8626 93.8926,54.8626 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  93.8926,54.8626 93.8926,369.674 110.113,369.674 110.113,54.8626 93.8926,54.8626 
  "/>
<polygon clip-path="url(#clip02)" points="
110.113,84.3762 110.113,369.674 126.333,369.674 126.333,84.3762 110.113,84.3762 110.113,84.3762 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  110.113,84.3762 110.113,369.674 126.333,369.674 126.333,84.3762 110.113,84.3762 
  "/>
<polygon clip-path="url(#clip02)" points="
126.333,137.501 126.333,369.674 142.553,369.674 142.553,137.501 126.333,137.501 126.333,137.501 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  126.333,137.501 126.333,369.674 142.553,369.674 142.553,137.501 126.333,137.501 
  "/>
<polygon clip-path="url(#clip02)" points="
142.553,182.755 142.553,369.674 158.772,369.674 158.772,182.755 142.553,182.755 142.553,182.755 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  142.553,182.755 142.553,369.674 158.772,369.674 158.772,182.755 142.553,182.755 
  "/>
<polygon clip-path="url(#clip02)" points="
158.772,210.301 158.772,369.674 174.992,369.674 174.992,210.301 158.772,210.301 158.772,210.301 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  158.772,210.301 158.772,369.674 174.992,369.674 174.992,210.301 158.772,210.301 
  "/>
<polygon clip-path="url(#clip02)" points="
174.992,255.555 174.992,369.674 191.212,369.674 191.212,255.555 174.992,255.555 174.992,255.555 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  174.992,255.555 174.992,369.674 191.212,369.674 191.212,255.555 174.992,255.555 
  "/>
<polygon clip-path="url(#clip02)" points="
191.212,269.328 191.212,369.674 207.432,369.674 207.432,269.328 191.212,269.328 191.212,269.328 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  191.212,269.328 191.212,369.674 207.432,369.674 207.432,269.328 191.212,269.328 
  "/>
<polygon clip-path="url(#clip02)" points="
207.432,304.744 207.432,369.674 223.652,369.674 223.652,304.744 207.432,304.744 207.432,304.744 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  207.432,304.744 207.432,369.674 223.652,369.674 223.652,304.744 207.432,304.744 
  "/>
<polygon clip-path="url(#clip02)" points="
223.652,324.42 223.652,369.674 239.872,369.674 239.872,324.42 223.652,324.42 223.652,324.42 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  223.652,324.42 223.652,369.674 239.872,369.674 239.872,324.42 223.652,324.42 
  "/>
<polygon clip-path="url(#clip02)" points="
239.872,342.128 239.872,369.674 256.092,369.674 256.092,342.128 239.872,342.128 239.872,342.128 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  239.872,342.128 239.872,369.674 256.092,369.674 256.092,342.128 239.872,342.128 
  "/>
<polygon clip-path="url(#clip02)" points="
256.092,349.998 256.092,369.674 272.312,369.674 272.312,349.998 256.092,349.998 256.092,349.998 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  256.092,349.998 256.092,369.674 272.312,369.674 272.312,349.998 256.092,349.998 
  "/>
<polygon clip-path="url(#clip02)" points="
272.312,348.031 272.312,369.674 288.532,369.674 288.532,348.031 272.312,348.031 272.312,348.031 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  272.312,348.031 272.312,369.674 288.532,369.674 288.532,348.031 272.312,348.031 
  "/>
<polygon clip-path="url(#clip02)" points="
288.532,349.998 288.532,369.674 304.752,369.674 304.752,349.998 288.532,349.998 288.532,349.998 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  288.532,349.998 288.532,369.674 304.752,369.674 304.752,349.998 288.532,349.998 
  "/>
<polygon clip-path="url(#clip02)" points="
304.752,353.934 304.752,369.674 320.972,369.674 320.972,353.934 304.752,353.934 304.752,353.934 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  304.752,353.934 304.752,369.674 320.972,369.674 320.972,353.934 304.752,353.934 
  "/>
<polygon clip-path="url(#clip02)" points="
320.972,369.674 320.972,369.674 337.192,369.674 337.192,369.674 320.972,369.674 320.972,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  320.972,369.674 320.972,369.674 337.192,369.674 320.972,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
337.192,361.804 337.192,369.674 353.412,369.674 353.412,361.804 337.192,361.804 337.192,361.804 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  337.192,361.804 337.192,369.674 353.412,369.674 353.412,361.804 337.192,361.804 
  "/>
<polygon clip-path="url(#clip02)" points="
353.412,365.739 353.412,369.674 369.632,369.674 369.632,365.739 353.412,365.739 353.412,365.739 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  353.412,365.739 353.412,369.674 369.632,369.674 369.632,365.739 353.412,365.739 
  "/>
<polygon clip-path="url(#clip02)" points="
369.632,367.707 369.632,369.674 385.852,369.674 385.852,367.707 369.632,367.707 369.632,367.707 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  369.632,367.707 369.632,369.674 385.852,369.674 385.852,367.707 369.632,367.707 
  "/>
<polygon clip-path="url(#clip02)" points="
385.852,365.739 385.852,369.674 402.072,369.674 402.072,365.739 385.852,365.739 385.852,365.739 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  385.852,365.739 385.852,369.674 402.072,369.674 402.072,365.739 385.852,365.739 
  "/>
<polygon clip-path="url(#clip02)" points="
402.072,369.674 402.072,369.674 418.292,369.674 418.292,369.674 402.072,369.674 402.072,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  402.072,369.674 402.072,369.674 418.292,369.674 402.072,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
418.292,369.674 418.292,369.674 434.512,369.674 434.512,369.674 418.292,369.674 418.292,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  418.292,369.674 418.292,369.674 434.512,369.674 418.292,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
434.512,369.674 434.512,369.674 450.732,369.674 450.732,369.674 434.512,369.674 434.512,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  434.512,369.674 434.512,369.674 450.732,369.674 434.512,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
450.732,367.707 450.732,369.674 466.952,369.674 466.952,367.707 450.732,367.707 450.732,367.707 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  450.732,367.707 450.732,369.674 466.952,369.674 466.952,367.707 450.732,367.707 
  "/>
<polygon clip-path="url(#clip02)" points="
466.952,369.674 466.952,369.674 483.172,369.674 483.172,369.674 466.952,369.674 466.952,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  466.952,369.674 466.952,369.674 483.172,369.674 466.952,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
483.172,369.674 483.172,369.674 499.392,369.674 499.392,369.674 483.172,369.674 483.172,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  483.172,369.674 483.172,369.674 499.392,369.674 483.172,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
499.392,369.674 499.392,369.674 515.612,369.674 515.612,369.674 499.392,369.674 499.392,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  499.392,369.674 499.392,369.674 515.612,369.674 499.392,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
515.612,369.674 515.612,369.674 531.832,369.674 531.832,369.674 515.612,369.674 515.612,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  515.612,369.674 515.612,369.674 531.832,369.674 515.612,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
531.832,367.707 531.832,369.674 548.052,369.674 548.052,367.707 531.832,367.707 531.832,367.707 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  531.832,367.707 531.832,369.674 548.052,369.674 548.052,367.707 531.832,367.707 
  "/>
<polygon clip-path="url(#clip02)" points="
548.052,369.674 548.052,369.674 564.272,369.674 564.272,369.674 548.052,369.674 548.052,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  548.052,369.674 548.052,369.674 564.272,369.674 548.052,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
564.272,367.707 564.272,369.674 580.492,369.674 580.492,367.707 564.272,367.707 564.272,367.707 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  564.272,367.707 564.272,369.674 580.492,369.674 580.492,367.707 564.272,367.707 
  "/>
<polygon clip-path="url(#clip00)" points="
505.547,74.5015 578.063,74.5015 578.063,44.2615 505.547,44.2615 
  " fill="#ffffff" fill-opacity="1"/>
<polyline clip-path="url(#clip00)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  505.547,74.5015 578.063,74.5015 578.063,44.2615 505.547,44.2615 505.547,74.5015 
  "/>
<polygon clip-path="url(#clip00)" points="
511.547,65.4295 547.547,65.4295 547.547,53.3335 511.547,53.3335 511.547,65.4295 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip00)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  511.547,65.4295 547.547,65.4295 547.547,53.3335 511.547,53.3335 511.547,65.4295 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 553.547, 63.8815)" x="553.547" y="63.8815">y1</text>
</g>
</svg>




In the prior tests all the matrix elements have been small.
Either normally distributes, mean 0 and variance 1,
or uniformly distributed between 0 and 1.
But what happens when we look at matrices with element larger values?
To do this, we crank up the variance on the `randn`.
That is to say we generate our trial matrices using
`variance*randn(T,size)`.
Results follow for variance 10 thousand, 10 million and 10 billion.

**Input:**

{% highlight julia %}
var10Knormal100double = generate_data(1000, (args...)->10_000*randn(args...), Float64, (100,100))
display_evaluation_figures(var10Knormal100double)
{% endhighlight %}

**Output:**

{% highlight plaintext %}
err_jl:	Q0=3.83e-18	 Q1=4.83e-18	 Q2=5.32e-18	 Q3=6.06e-18	 Q4=1.18e-17
err_tf:	Q0=7.46e-18	 Q1=1.16e-17	 Q2=1.29e-17	 Q3=1.46e-17	 Q4=2.15e-17

{% endhighlight %}

{% highlight plaintext %}
INFO: binning = auto

{% endhighlight %}




<?xml version="1.0" encoding="utf-8"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="600" height="400" viewBox="0 0 600 400">
<defs>
  <clipPath id="clip00">
    <rect x="0" y="0" width="600" height="400"/>
  </clipPath>
</defs>
<polygon clip-path="url(#clip00)" points="
0,400 600,400 600,0 0,0 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip01">
    <rect x="120" y="0" width="421" height="400"/>
  </clipPath>
</defs>
<polygon clip-path="url(#clip00)" points="
45.8815,369.674 596.063,369.674 596.063,23.3815 45.8815,23.3815 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip02">
    <rect x="45" y="23" width="551" height="347"/>
  </clipPath>
</defs>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  88.7705,364.48 88.7705,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  225.36,364.48 225.36,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  361.949,364.48 361.949,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  498.538,364.48 498.538,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,369.674 587.81,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,261.862 587.81,261.862 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,154.05 587.81,154.05 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,46.2376 587.81,46.2376 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 596.063,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  88.7705,369.674 88.7705,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  225.36,369.674 225.36,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  361.949,369.674 361.949,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  498.538,369.674 498.538,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 45.8815,23.3815 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 54.1342,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,261.862 54.1342,261.862 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,154.05 54.1342,154.05 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,46.2376 54.1342,46.2376 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 88.7705, 381.674)" x="88.7705" y="381.674">1</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 225.36, 381.674)" x="225.36" y="381.674">2</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 361.949, 381.674)" x="361.949" y="381.674">3</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 498.538, 381.674)" x="498.538" y="381.674">4</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 374.174)" x="44.6815" y="374.174">0</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 266.362)" x="44.6815" y="266.362">50</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 158.55)" x="44.6815" y="158.55">100</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 50.7376)" x="44.6815" y="50.7376">150</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:21; text-anchor:middle;" transform="rotate(0, 320.972, 18)" x="320.972" y="18">Histogram of relative error values for SVD reconstruction</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:16; text-anchor:middle;" transform="rotate(0, 320.972, 397.6)" x="320.972" y="397.6">factor by which Tensorflow error is greater than Julia (LAPACK) error</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:16; text-anchor:middle;" transform="rotate(-90, 14.4, 196.528)" x="14.4" y="196.528">number of trials with this error</text>
</g>
<polygon clip-path="url(#clip02)" points="
61.4526,363.205 61.4526,369.674 88.7705,369.674 88.7705,363.205 61.4526,363.205 61.4526,363.205 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  61.4526,363.205 61.4526,369.674 88.7705,369.674 88.7705,363.205 61.4526,363.205 
  "/>
<polygon clip-path="url(#clip02)" points="
88.7705,348.112 88.7705,369.674 116.088,369.674 116.088,348.112 88.7705,348.112 88.7705,348.112 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  88.7705,348.112 88.7705,369.674 116.088,369.674 116.088,348.112 88.7705,348.112 
  "/>
<polygon clip-path="url(#clip02)" points="
116.088,309.299 116.088,369.674 143.406,369.674 143.406,309.299 116.088,309.299 116.088,309.299 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  116.088,309.299 116.088,369.674 143.406,369.674 143.406,309.299 116.088,309.299 
  "/>
<polygon clip-path="url(#clip02)" points="
143.406,292.049 143.406,369.674 170.724,369.674 170.724,292.049 143.406,292.049 143.406,292.049 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  143.406,292.049 143.406,369.674 170.724,369.674 170.724,292.049 143.406,292.049 
  "/>
<polygon clip-path="url(#clip02)" points="
170.724,216.581 170.724,369.674 198.042,369.674 198.042,216.581 170.724,216.581 170.724,216.581 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  170.724,216.581 170.724,369.674 198.042,369.674 198.042,216.581 170.724,216.581 
  "/>
<polygon clip-path="url(#clip02)" points="
198.042,171.3 198.042,369.674 225.36,369.674 225.36,171.3 198.042,171.3 198.042,171.3 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  198.042,171.3 198.042,369.674 225.36,369.674 225.36,171.3 198.042,171.3 
  "/>
<polygon clip-path="url(#clip02)" points="
225.36,136.8 225.36,369.674 252.678,369.674 252.678,136.8 225.36,136.8 225.36,136.8 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  225.36,136.8 225.36,369.674 252.678,369.674 252.678,136.8 225.36,136.8 
  "/>
<polygon clip-path="url(#clip02)" points="
252.678,59.1751 252.678,369.674 279.995,369.674 279.995,59.1751 252.678,59.1751 252.678,59.1751 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  252.678,59.1751 252.678,369.674 279.995,369.674 279.995,59.1751 252.678,59.1751 
  "/>
<polygon clip-path="url(#clip02)" points="
279.995,54.8626 279.995,369.674 307.313,369.674 307.313,54.8626 279.995,54.8626 279.995,54.8626 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  279.995,54.8626 279.995,369.674 307.313,369.674 307.313,54.8626 279.995,54.8626 
  "/>
<polygon clip-path="url(#clip02)" points="
307.313,130.331 307.313,369.674 334.631,369.674 334.631,130.331 307.313,130.331 307.313,130.331 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  307.313,130.331 307.313,369.674 334.631,369.674 334.631,130.331 307.313,130.331 
  "/>
<polygon clip-path="url(#clip02)" points="
334.631,162.675 334.631,369.674 361.949,369.674 361.949,162.675 334.631,162.675 334.631,162.675 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  334.631,162.675 334.631,369.674 361.949,369.674 361.949,162.675 334.631,162.675 
  "/>
<polygon clip-path="url(#clip02)" points="
361.949,233.831 361.949,369.674 389.267,369.674 389.267,233.831 361.949,233.831 361.949,233.831 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  361.949,233.831 361.949,369.674 389.267,369.674 389.267,233.831 361.949,233.831 
  "/>
<polygon clip-path="url(#clip02)" points="
389.267,285.581 389.267,369.674 416.585,369.674 416.585,285.581 389.267,285.581 389.267,285.581 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  389.267,285.581 389.267,369.674 416.585,369.674 416.585,285.581 389.267,285.581 
  "/>
<polygon clip-path="url(#clip02)" points="
416.585,307.143 416.585,369.674 443.903,369.674 443.903,307.143 416.585,307.143 416.585,307.143 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  416.585,307.143 416.585,369.674 443.903,369.674 443.903,307.143 416.585,307.143 
  "/>
<polygon clip-path="url(#clip02)" points="
443.903,341.643 443.903,369.674 471.22,369.674 471.22,341.643 443.903,341.643 443.903,341.643 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  443.903,341.643 443.903,369.674 471.22,369.674 471.22,341.643 443.903,341.643 
  "/>
<polygon clip-path="url(#clip02)" points="
471.22,358.893 471.22,369.674 498.538,369.674 498.538,358.893 471.22,358.893 471.22,358.893 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  471.22,358.893 471.22,369.674 498.538,369.674 498.538,358.893 471.22,358.893 
  "/>
<polygon clip-path="url(#clip02)" points="
498.538,365.362 498.538,369.674 525.856,369.674 525.856,365.362 498.538,365.362 498.538,365.362 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  498.538,365.362 498.538,369.674 525.856,369.674 525.856,365.362 498.538,365.362 
  "/>
<polygon clip-path="url(#clip02)" points="
525.856,365.362 525.856,369.674 553.174,369.674 553.174,365.362 525.856,365.362 525.856,365.362 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  525.856,365.362 525.856,369.674 553.174,369.674 553.174,365.362 525.856,365.362 
  "/>
<polygon clip-path="url(#clip02)" points="
553.174,365.362 553.174,369.674 580.492,369.674 580.492,365.362 553.174,365.362 553.174,365.362 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  553.174,365.362 553.174,369.674 580.492,369.674 580.492,365.362 553.174,365.362 
  "/>
<polygon clip-path="url(#clip00)" points="
505.547,74.5015 578.063,74.5015 578.063,44.2615 505.547,44.2615 
  " fill="#ffffff" fill-opacity="1"/>
<polyline clip-path="url(#clip00)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  505.547,74.5015 578.063,74.5015 578.063,44.2615 505.547,44.2615 505.547,74.5015 
  "/>
<polygon clip-path="url(#clip00)" points="
511.547,65.4295 547.547,65.4295 547.547,53.3335 511.547,53.3335 511.547,65.4295 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip00)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  511.547,65.4295 547.547,65.4295 547.547,53.3335 511.547,53.3335 511.547,65.4295 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 553.547, 63.8815)" x="553.547" y="63.8815">y1</text>
</g>
</svg>




**Input:**

{% highlight julia %}
var10Mnormal100double = generate_data(1000, (args...)->10_000_000*randn(args...), Float64, (100,100))
display_evaluation_figures(var10Mnormal100double)
{% endhighlight %}

**Output:**

{% highlight plaintext %}
err_jl:	Q0=3.74e-12	 Q1=4.85e-12	 Q2=5.37e-12	 Q3=6.15e-12	 Q4=1.10e-11
err_tf:	Q0=7.98e-12	 Q1=1.17e-11	 Q2=1.32e-11	 Q3=1.48e-11	 Q4=2.38e-11

{% endhighlight %}

{% highlight plaintext %}
INFO: binning = auto

{% endhighlight %}




<?xml version="1.0" encoding="utf-8"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="600" height="400" viewBox="0 0 600 400">
<defs>
  <clipPath id="clip00">
    <rect x="0" y="0" width="600" height="400"/>
  </clipPath>
</defs>
<polygon clip-path="url(#clip00)" points="
0,400 600,400 600,0 0,0 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip01">
    <rect x="120" y="0" width="421" height="400"/>
  </clipPath>
</defs>
<polygon clip-path="url(#clip00)" points="
45.8815,369.674 596.063,369.674 596.063,23.3815 45.8815,23.3815 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip02">
    <rect x="45" y="23" width="551" height="347"/>
  </clipPath>
</defs>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  61.4526,364.48 61.4526,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  198.042,364.48 198.042,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  334.631,364.48 334.631,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  471.22,364.48 471.22,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,369.674 587.81,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,253.077 587.81,253.077 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,136.48 587.81,136.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 596.063,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  61.4526,369.674 61.4526,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  198.042,369.674 198.042,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  334.631,369.674 334.631,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  471.22,369.674 471.22,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 45.8815,23.3815 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 54.1342,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,253.077 54.1342,253.077 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,136.48 54.1342,136.48 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 61.4526, 381.674)" x="61.4526" y="381.674">1</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 198.042, 381.674)" x="198.042" y="381.674">2</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 334.631, 381.674)" x="334.631" y="381.674">3</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 471.22, 381.674)" x="471.22" y="381.674">4</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 374.174)" x="44.6815" y="374.174">0</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 257.577)" x="44.6815" y="257.577">50</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 140.98)" x="44.6815" y="140.98">100</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:21; text-anchor:middle;" transform="rotate(0, 320.972, 18)" x="320.972" y="18">Histogram of relative error values for SVD reconstruction</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:16; text-anchor:middle;" transform="rotate(0, 320.972, 397.6)" x="320.972" y="397.6">factor by which Tensorflow error is greater than Julia (LAPACK) error</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:16; text-anchor:middle;" transform="rotate(-90, 14.4, 196.528)" x="14.4" y="196.528">number of trials with this error</text>
</g>
<polygon clip-path="url(#clip02)" points="
61.4526,358.014 61.4526,369.674 88.7705,369.674 88.7705,358.014 61.4526,358.014 61.4526,358.014 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  61.4526,358.014 61.4526,369.674 88.7705,369.674 88.7705,358.014 61.4526,358.014 
  "/>
<polygon clip-path="url(#clip02)" points="
88.7705,330.031 88.7705,369.674 116.088,369.674 116.088,330.031 88.7705,330.031 88.7705,330.031 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  88.7705,330.031 88.7705,369.674 116.088,369.674 116.088,330.031 88.7705,330.031 
  "/>
<polygon clip-path="url(#clip02)" points="
116.088,269.401 116.088,369.674 143.406,369.674 143.406,269.401 116.088,269.401 116.088,269.401 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  116.088,269.401 116.088,369.674 143.406,369.674 143.406,269.401 116.088,269.401 
  "/>
<polygon clip-path="url(#clip02)" points="
143.406,220.43 143.406,369.674 170.724,369.674 170.724,220.43 143.406,220.43 143.406,220.43 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  143.406,220.43 143.406,369.674 170.724,369.674 170.724,220.43 143.406,220.43 
  "/>
<polygon clip-path="url(#clip02)" points="
170.724,96.8375 170.724,369.674 198.042,369.674 198.042,96.8375 170.724,96.8375 170.724,96.8375 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  170.724,96.8375 170.724,369.674 198.042,369.674 198.042,96.8375 170.724,96.8375 
  "/>
<polygon clip-path="url(#clip02)" points="
198.042,106.165 198.042,369.674 225.36,369.674 225.36,106.165 198.042,106.165 198.042,106.165 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  198.042,106.165 198.042,369.674 225.36,369.674 225.36,106.165 198.042,106.165 
  "/>
<polygon clip-path="url(#clip02)" points="
225.36,54.8626 225.36,369.674 252.678,369.674 252.678,54.8626 225.36,54.8626 225.36,54.8626 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  225.36,54.8626 225.36,369.674 252.678,369.674 252.678,54.8626 225.36,54.8626 
  "/>
<polygon clip-path="url(#clip02)" points="
252.678,68.8542 252.678,369.674 279.995,369.674 279.995,68.8542 252.678,68.8542 252.678,68.8542 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  252.678,68.8542 252.678,369.674 279.995,369.674 279.995,68.8542 252.678,68.8542 
  "/>
<polygon clip-path="url(#clip02)" points="
279.995,110.829 279.995,369.674 307.313,369.674 307.313,110.829 279.995,110.829 279.995,110.829 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  279.995,110.829 279.995,369.674 307.313,369.674 307.313,110.829 279.995,110.829 
  "/>
<polygon clip-path="url(#clip02)" points="
307.313,143.476 307.313,369.674 334.631,369.674 334.631,143.476 307.313,143.476 307.313,143.476 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  307.313,143.476 307.313,369.674 334.631,369.674 334.631,143.476 307.313,143.476 
  "/>
<polygon clip-path="url(#clip02)" points="
334.631,236.754 334.631,369.674 361.949,369.674 361.949,236.754 334.631,236.754 334.631,236.754 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  334.631,236.754 334.631,369.674 361.949,369.674 361.949,236.754 334.631,236.754 
  "/>
<polygon clip-path="url(#clip02)" points="
361.949,262.405 361.949,369.674 389.267,369.674 389.267,262.405 361.949,262.405 361.949,262.405 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  361.949,262.405 361.949,369.674 389.267,369.674 389.267,262.405 361.949,262.405 
  "/>
<polygon clip-path="url(#clip02)" points="
389.267,304.38 389.267,369.674 416.585,369.674 416.585,304.38 389.267,304.38 389.267,304.38 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  389.267,304.38 389.267,369.674 416.585,369.674 416.585,304.38 389.267,304.38 
  "/>
<polygon clip-path="url(#clip02)" points="
416.585,323.035 416.585,369.674 443.903,369.674 443.903,323.035 416.585,323.035 416.585,323.035 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  416.585,323.035 416.585,369.674 443.903,369.674 443.903,323.035 416.585,323.035 
  "/>
<polygon clip-path="url(#clip02)" points="
443.903,346.355 443.903,369.674 471.22,369.674 471.22,346.355 443.903,346.355 443.903,346.355 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  443.903,346.355 443.903,369.674 471.22,369.674 471.22,346.355 443.903,346.355 
  "/>
<polygon clip-path="url(#clip02)" points="
471.22,362.678 471.22,369.674 498.538,369.674 498.538,362.678 471.22,362.678 471.22,362.678 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  471.22,362.678 471.22,369.674 498.538,369.674 498.538,362.678 471.22,362.678 
  "/>
<polygon clip-path="url(#clip02)" points="
498.538,362.678 498.538,369.674 525.856,369.674 525.856,362.678 498.538,362.678 498.538,362.678 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  498.538,362.678 498.538,369.674 525.856,369.674 525.856,362.678 498.538,362.678 
  "/>
<polygon clip-path="url(#clip02)" points="
525.856,369.674 525.856,369.674 553.174,369.674 553.174,369.674 525.856,369.674 525.856,369.674 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  525.856,369.674 525.856,369.674 553.174,369.674 525.856,369.674 
  "/>
<polygon clip-path="url(#clip02)" points="
553.174,365.01 553.174,369.674 580.492,369.674 580.492,365.01 553.174,365.01 553.174,365.01 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  553.174,365.01 553.174,369.674 580.492,369.674 580.492,365.01 553.174,365.01 
  "/>
<polygon clip-path="url(#clip00)" points="
505.547,74.5015 578.063,74.5015 578.063,44.2615 505.547,44.2615 
  " fill="#ffffff" fill-opacity="1"/>
<polyline clip-path="url(#clip00)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  505.547,74.5015 578.063,74.5015 578.063,44.2615 505.547,44.2615 505.547,74.5015 
  "/>
<polygon clip-path="url(#clip00)" points="
511.547,65.4295 547.547,65.4295 547.547,53.3335 511.547,53.3335 511.547,65.4295 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip00)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  511.547,65.4295 547.547,65.4295 547.547,53.3335 511.547,53.3335 511.547,65.4295 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 553.547, 63.8815)" x="553.547" y="63.8815">y1</text>
</g>
</svg>




**Input:**

{% highlight julia %}
var10Gnormal100double = generate_data(1000, (args...)->10_000_000_000*randn(args...), Float64, (100,100))
display_evaluation_figures(var10Gnormal100double)
{% endhighlight %}

**Output:**

{% highlight plaintext %}
err_jl:	Q0=3.80e-06	 Q1=4.91e-06	 Q2=5.40e-06	 Q3=6.22e-06	 Q4=1.07e-05
err_tf:	Q0=7.85e-06	 Q1=1.16e-05	 Q2=1.30e-05	 Q3=1.46e-05	 Q4=2.20e-05

{% endhighlight %}

{% highlight plaintext %}
INFO: binning = auto

{% endhighlight %}




<?xml version="1.0" encoding="utf-8"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="600" height="400" viewBox="0 0 600 400">
<defs>
  <clipPath id="clip00">
    <rect x="0" y="0" width="600" height="400"/>
  </clipPath>
</defs>
<polygon clip-path="url(#clip00)" points="
0,400 600,400 600,0 0,0 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip01">
    <rect x="120" y="0" width="421" height="400"/>
  </clipPath>
</defs>
<polygon clip-path="url(#clip00)" points="
45.8815,369.674 596.063,369.674 596.063,23.3815 45.8815,23.3815 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip02">
    <rect x="45" y="23" width="551" height="347"/>
  </clipPath>
</defs>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  61.4526,364.48 61.4526,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  198.042,364.48 198.042,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  334.631,364.48 334.631,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  471.22,364.48 471.22,28.5758 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,369.674 587.81,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,250.427 587.81,250.427 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  54.1342,131.181 587.81,131.181 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 596.063,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  61.4526,369.674 61.4526,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  198.042,369.674 198.042,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  334.631,369.674 334.631,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  471.22,369.674 471.22,364.48 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 45.8815,23.3815 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,369.674 54.1342,369.674 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,250.427 54.1342,250.427 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  45.8815,131.181 54.1342,131.181 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 61.4526, 381.674)" x="61.4526" y="381.674">1</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 198.042, 381.674)" x="198.042" y="381.674">2</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 334.631, 381.674)" x="334.631" y="381.674">3</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 471.22, 381.674)" x="471.22" y="381.674">4</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 374.174)" x="44.6815" y="374.174">0</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 254.927)" x="44.6815" y="254.927">50</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 44.6815, 135.681)" x="44.6815" y="135.681">100</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:21; text-anchor:middle;" transform="rotate(0, 320.972, 18)" x="320.972" y="18">Histogram of relative error values for SVD reconstruction</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:16; text-anchor:middle;" transform="rotate(0, 320.972, 397.6)" x="320.972" y="397.6">factor by which Tensorflow error is greater than Julia (LAPACK) error</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:16; text-anchor:middle;" transform="rotate(-90, 14.4, 196.528)" x="14.4" y="196.528">number of trials with this error</text>
</g>
<polygon clip-path="url(#clip02)" points="
61.4526,367.289 61.4526,369.674 88.7705,369.674 88.7705,367.289 61.4526,367.289 61.4526,367.289 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  61.4526,367.289 61.4526,369.674 88.7705,369.674 88.7705,367.289 61.4526,367.289 
  "/>
<polygon clip-path="url(#clip02)" points="
88.7705,307.666 88.7705,369.674 116.088,369.674 116.088,307.666 88.7705,307.666 88.7705,307.666 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  88.7705,307.666 88.7705,369.674 116.088,369.674 116.088,307.666 88.7705,307.666 
  "/>
<polygon clip-path="url(#clip02)" points="
116.088,262.352 116.088,369.674 143.406,369.674 143.406,262.352 116.088,262.352 116.088,262.352 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  116.088,262.352 116.088,369.674 143.406,369.674 143.406,262.352 116.088,262.352 
  "/>
<polygon clip-path="url(#clip02)" points="
143.406,174.109 143.406,369.674 170.724,369.674 170.724,174.109 143.406,174.109 143.406,174.109 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  143.406,174.109 143.406,369.674 170.724,369.674 170.724,174.109 143.406,174.109 
  "/>
<polygon clip-path="url(#clip02)" points="
170.724,83.4818 170.724,369.674 198.042,369.674 198.042,83.4818 170.724,83.4818 170.724,83.4818 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  170.724,83.4818 170.724,369.674 198.042,369.674 198.042,83.4818 170.724,83.4818 
  "/>
<polygon clip-path="url(#clip02)" points="
198.042,100.176 198.042,369.674 225.36,369.674 225.36,100.176 198.042,100.176 198.042,100.176 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  198.042,100.176 198.042,369.674 225.36,369.674 225.36,100.176 198.042,100.176 
  "/>
<polygon clip-path="url(#clip02)" points="
225.36,59.6325 225.36,369.674 252.678,369.674 252.678,59.6325 225.36,59.6325 225.36,59.6325 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  225.36,59.6325 225.36,369.674 252.678,369.674 252.678,59.6325 225.36,59.6325 
  "/>
<polygon clip-path="url(#clip02)" points="
252.678,54.8626 252.678,369.674 279.995,369.674 279.995,54.8626 252.678,54.8626 252.678,54.8626 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  252.678,54.8626 252.678,369.674 279.995,369.674 279.995,54.8626 252.678,54.8626 
  "/>
<polygon clip-path="url(#clip02)" points="
279.995,104.946 279.995,369.674 307.313,369.674 307.313,104.946 279.995,104.946 279.995,104.946 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  279.995,104.946 279.995,369.674 307.313,369.674 307.313,104.946 279.995,104.946 
  "/>
<polygon clip-path="url(#clip02)" points="
307.313,178.879 307.313,369.674 334.631,369.674 334.631,178.879 307.313,178.879 307.313,178.879 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  307.313,178.879 307.313,369.674 334.631,369.674 334.631,178.879 307.313,178.879 
  "/>
<polygon clip-path="url(#clip02)" points="
334.631,233.733 334.631,369.674 361.949,369.674 361.949,233.733 334.631,233.733 334.631,233.733 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  334.631,233.733 334.631,369.674 361.949,369.674 361.949,233.733 334.631,233.733 
  "/>
<polygon clip-path="url(#clip02)" points="
361.949,264.737 361.949,369.674 389.267,369.674 389.267,264.737 361.949,264.737 361.949,264.737 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  361.949,264.737 361.949,369.674 389.267,369.674 389.267,264.737 361.949,264.737 
  "/>
<polygon clip-path="url(#clip02)" points="
389.267,314.821 389.267,369.674 416.585,369.674 416.585,314.821 389.267,314.821 389.267,314.821 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  389.267,314.821 389.267,369.674 416.585,369.674 416.585,314.821 389.267,314.821 
  "/>
<polygon clip-path="url(#clip02)" points="
416.585,348.21 416.585,369.674 443.903,369.674 443.903,348.21 416.585,348.21 416.585,348.21 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  416.585,348.21 416.585,369.674 443.903,369.674 443.903,348.21 416.585,348.21 
  "/>
<polygon clip-path="url(#clip02)" points="
443.903,329.13 443.903,369.674 471.22,369.674 471.22,329.13 443.903,329.13 443.903,329.13 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  443.903,329.13 443.903,369.674 471.22,369.674 471.22,329.13 443.903,329.13 
  "/>
<polygon clip-path="url(#clip02)" points="
471.22,362.519 471.22,369.674 498.538,369.674 498.538,362.519 471.22,362.519 471.22,362.519 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  471.22,362.519 471.22,369.674 498.538,369.674 498.538,362.519 471.22,362.519 
  "/>
<polygon clip-path="url(#clip02)" points="
498.538,364.904 498.538,369.674 525.856,369.674 525.856,364.904 498.538,364.904 498.538,364.904 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  498.538,364.904 498.538,369.674 525.856,369.674 525.856,364.904 498.538,364.904 
  "/>
<polygon clip-path="url(#clip02)" points="
525.856,362.519 525.856,369.674 553.174,369.674 553.174,362.519 525.856,362.519 525.856,362.519 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  525.856,362.519 525.856,369.674 553.174,369.674 553.174,362.519 525.856,362.519 
  "/>
<polygon clip-path="url(#clip02)" points="
553.174,364.904 553.174,369.674 580.492,369.674 580.492,364.904 553.174,364.904 553.174,364.904 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip02)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  553.174,364.904 553.174,369.674 580.492,369.674 580.492,364.904 553.174,364.904 
  "/>
<polygon clip-path="url(#clip00)" points="
505.547,74.5015 578.063,74.5015 578.063,44.2615 505.547,44.2615 
  " fill="#ffffff" fill-opacity="1"/>
<polyline clip-path="url(#clip00)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  505.547,74.5015 578.063,74.5015 578.063,44.2615 505.547,44.2615 505.547,74.5015 
  "/>
<polygon clip-path="url(#clip00)" points="
511.547,65.4295 547.547,65.4295 547.547,53.3335 511.547,53.3335 511.547,65.4295 
  " fill="#0099ff" fill-opacity="1"/>
<polyline clip-path="url(#clip00)" style="stroke:#00002d; stroke-width:0.8; stroke-opacity:1; fill:none" points="
  511.547,65.4295 547.547,65.4295 547.547,53.3335 511.547,53.3335 511.547,65.4295 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#00002d; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 553.547, 63.8815)" x="553.547" y="63.8815">y1</text>
</g>
</svg>




What we see here, is that the distribution of relative errors remains the same, but the absolute errors increase.
i.e. TensorFlow is still generally has around 2.5 times the error of Julia.
Further for both TensorFlow and Julia, those absolute errors are increasing quadratically with the variance.
This is due to the use of sum of squared error, if we did sum of error, it would be linear increase.
So at high variance, this difference in accuracy could matter.
Since we are now looking at differences of $10^{-6}$ for example.
However, these differences remain small compared to the values in the matrix eg $10^7$.

In the end, the differences are not relevant to most people (Potentially not relevant to anyone).
It is merely a curiosity.
LAPACK is consistently better at SVD than TensorFlow.
Really, one should not be too surprised given that having excellent matrix factorisation is what LAPACK is all about.

**Input:**

{% highlight julia %}

{% endhighlight %}
