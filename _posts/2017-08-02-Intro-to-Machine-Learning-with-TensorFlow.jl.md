---
layout: default
title: "Intro to Machine Learning with TensorFlow.jl"
tags:
    - julia
    - jupyter-notebook
redirect_from: 
    - NNforNLPBook/NNexamples
    
---
In this blog post, I am going to go through as series of neural network structures.
This is intended as a demonstration of the more basic neural net functionality.
This blog post serves as an accompanyment to the introduction to machine learning chapter of the short book I am writing (
Currently under the working title "Neural Network Representations for Natural Language Processing")
<!--more-->

I do have an [earlier blog covering some similar topics]({{site.url}}/2017/01/24/JuliaML-and-TensorFlow-Tuitorial.html).
However, I exect the code in this one to be a lot more sensible,
since I am now much more familar with TensorFlow.jl, having now written a significant chunk of it.
Also MLDataUtils.jl is in different state to what it was.


**Input:**

{% highlight julia %}
using TensorFlow
using MLDataUtils
using MLDatasets

using ProgressMeter

using Base.Test
using Plots
gr()
using FileIO
using ImageCore
{% endhighlight %}

# MNIST classifier

This is the most common benchmark for neural network classifiers.
[MNIST](http://yann.lecun.com/exdb/mnist/) is a collection of hand written digits from 0 to 9.
The task is to determine which digit is being shown.
With neural networks this is done by flattening the images into vectors, 
and using one-hot encoded outputs with softmax.

**Input:**

{% highlight julia %}
"""Makes 1 hot, row encoded labels."""
onehot_encode_labels(labels_raw) = convertlabel(LabelEnc.OneOfK, labels_raw, LabelEnc.NativeLabels(collect(0:9)),  LearnBase.ObsDim.First())
"""Convert 3D matrix of row,column,observation to vector,observation"""
flatten_images(img_raw) = squeeze(mapslices(vec, img_raw,1:2),2)




@testset "data prep" begin
    @test onehot_encode_labels([4,1,2,3,0]) == [0 0 0 0 1 0 0 0 0 0
                                  0 1 0 0 0 0 0 0 0 0
                                  0 0 1 0 0 0 0 0 0 0
                                  0 0 0 1 0 0 0 0 0 0
                                  1 0 0 0 0 0 0 0 0 0]
    
    data_b1 = flatten_images(MNIST.traintensor())
    @test size(data_b1) == (28*28, 60_000)
    labels_b1 = onehot_encode_labels(MNIST.trainlabels())
    @test size(labels_b1) == (60_000, 10)
end;
{% endhighlight %}

**Output:**

{% highlight plaintext %}
Test Summary: | Pass  Total
data prep     |    3      3

{% endhighlight %}

A visualisation of one of the examples from MNIST.
Code is a little complex because of the unflattening, and adding a border.

**Input:**

{% highlight julia %}
const frames_image_res = 30

"Convests a image vector into a framed 2D image"
function one_image(img::Vector)
    ret = zeros((frames_image_res, frames_image_res))
    ret[2:end-1, 2:end-1] = 1-rotl90(reshape(img, (28,28)))
    ret
end

train_images=flatten_images(MNIST.traintensor())
heatmap(one_image(train_images[:,10]))
{% endhighlight %}

**Output:**




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
39.3701,368.504 592.126,368.504 592.126,7.87402 39.3701,7.87402 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip02">
    <rect x="39" y="7" width="494" height="362"/>
  </clipPath>
</defs>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  195.409,363.094 195.409,13.2835 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  359.661,363.094 359.661,13.2835 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  523.913,363.094 523.913,13.2835 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  46.7614,254.304 524.735,254.304 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  46.7614,134.094 524.735,134.094 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  46.7614,13.8845 524.735,13.8845 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,368.504 532.126,368.504 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  195.409,368.504 195.409,363.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  359.661,368.504 359.661,363.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  523.913,368.504 523.913,363.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,368.504 39.3701,7.87402 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,254.304 46.7614,254.304 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,134.094 46.7614,134.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,13.8845 46.7614,13.8845 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 195.409, 382.304)" x="195.409" y="382.304">10</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 359.661, 382.304)" x="359.661" y="382.304">20</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 523.913, 382.304)" x="523.913" y="382.304">30</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 33.3701, 258.804)" x="33.3701" y="258.804">10</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 33.3701, 138.594)" x="33.3701" y="138.594">20</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 33.3701, 18.3845)" x="33.3701" y="18.3845">30</text>
</g>
<g clip-path="url(#clip02)">
<image width="493" height="361" xlink:href="data:;base64,
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
NgCEEG0ACPEvz17a9x+Mp2AAAAAASUVORK5CYII=
" transform="translate(39, 8)"/>
</g>
<defs>
  <clipPath id="clip03">
    <rect x="544" y="7" width="19" height="362"/>
  </clipPath>
</defs>
<g clip-path="url(#clip03)">
<image width="18" height="361" xlink:href="data:;base64,
iVBORw0KGgoAAAANSUhEUgAAABIAAAFpCAYAAACRXHjhAAACEUlEQVR4nO3c0W3EMAyDYafI/lN0
y17jjpCXD8UPwR6AMElR8hkXX5/ney+wvgTIWmvdz/4YoI2AHLX9zKVWc42JPVgjR22pynZAR6O3
Jan9ICAVkaJGiNq1fwmQpGZ2dF8IKEhtIdcmazSa2mOA1I6SGvWoIdcUtdn2G7GD9rspMlejov3H
tX8EIvdQUqMd00jab8Tu1dFgjSS1GhCK2mSNitRMQugN+2WAoP1mR/IammlUo6Z2NFsjg8U0KtrP
2sg27IIdUgENruxg+ndNo2T6c6FVBenSn2tsueaftH9s+mFl96jFXDsReV9Far3KrhXk/eTmWk6j
IrUaUFCjZy61HNBgjeQfvWPUkhrFjn6D7R9MbbRGay41N/sJTnGu9Y41DyrIyRo5agSmSa3nmqps
1iGDja2WftnYENBJ/ztQMf0ICB79zCoe/QhMkprq2cmTvwLKUduM2uTGpoAG229wio1tsEaQWq2y
4ThCQL0fNWdkvwMVT2w1oMkaGZxkzz72vwJt9C1MkhoC6s21ydRcY0PfQaodyQtNRK3Y/MdSy/Xs
YPpdaHtzzYWW2V/TyFX2sf8VaKNvhYsaXT1q6MEJBSRDq6hdLCI1jZj9xdCi14agRrW3xkan/9j/
smCHRO/NBKlt9WpVr0O6iBz731bQtcmV7ajlenbNtXvn3s9m1FbuJmLVGhvbUdL+udQQ0B+p8+fh
sEs94QAAAABJRU5ErkJggg==
" transform="translate(544, 8)"/>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 371.917)" x="568.126" y="371.917">0</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 335.854)" x="568.126" y="335.854">0.1</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 299.791)" x="568.126" y="299.791">0.2</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 263.728)" x="568.126" y="263.728">0.3</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 227.665)" x="568.126" y="227.665">0.4</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 191.602)" x="568.126" y="191.602">0.5</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 155.539)" x="568.126" y="155.539">0.6</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 119.476)" x="568.126" y="119.476">0.7</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 83.4128)" x="568.126" y="83.4128">0.8</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 47.3498)" x="568.126" y="47.3498">0.9</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 11.2868)" x="568.126" y="11.2868">1.0</text>
</g>
</svg>




In this basic example we use a traditional sigmoid feed-forward neural net.
It uses just a single wide hidden layer.
It works surprisingly well compaired to early benchmarks.
This is becuase the layer is very wide compaired to what was possible 30 years ago.

**Input:**

{% highlight julia %}
load("Intro\ to\ Machine\ Learning\ with\ Tensorflow.jl/mnist-basic.png")
{% endhighlight %}

**Output:**




![png]({{site.url}}/posts_assets/Intro to Machine Learning with TensorFlow.jl_files/Intro to Machine Learning with TensorFlow.jl_8_0.png)



**Input:**

{% highlight julia %}
sess = Session(Graph())
@tf begin
    X = placeholder(Float32, shape=[-1, 28*28])
    Y = placeholder(Float32, shape=[-1, 10])

    W1 = get_variable([28*28, 1024], Float32)
    b1 = get_variable([1024], Float32)
    Z1 = nn.sigmoid(X*W1 + b1)

    W2 = get_variable([1024, 10], Float32)
    b2 = get_variable([10], Float32)
    Z2 = Z1*W2 + b2 # Affine layer on its own, to get the unscaled logits
    Y_probs = nn.softmax(Z2)

    losses = nn.softmax_cross_entropy_with_logits(;logits=Z2, labels=Y) #This loss function takes the unscaled logits
    loss = reduce_mean(losses)
    optimizer = train.minimize(train.AdamOptimizer(), loss)
end

{% endhighlight %}

**Output:**

{% highlight plaintext %}
2017-08-02 18:53:18.598588: W tensorflow/core/platform/cpu_feature_guard.cc:45] The TensorFlow library wasn't compiled to use SSE4.1 instructions, but these are available on your machine and could speed up CPU computations.
2017-08-02 18:53:18.598620: W tensorflow/core/platform/cpu_feature_guard.cc:45] The TensorFlow library wasn't compiled to use SSE4.2 instructions, but these are available on your machine and could speed up CPU computations.
2017-08-02 18:53:18.598626: W tensorflow/core/platform/cpu_feature_guard.cc:45] The TensorFlow library wasn't compiled to use AVX instructions, but these are available on your machine and could speed up CPU computations.
2017-08-02 18:53:18.789486: I tensorflow/stream_executor/cuda/cuda_gpu_executor.cc:893] successful NUMA node read from SysFS had negative value (-1), but there must be at least one NUMA node, so returning NUMA node zero
2017-08-02 18:53:18.789997: I tensorflow/core/common_runtime/gpu/gpu_device.cc:940] Found device 0 with properties: 
name: GeForce GTX TITAN X
major: 5 minor: 2 memoryClockRate (GHz) 1.076
pciBusID 0000:01:00.0
Total memory: 11.91GiB
Free memory: 11.42GiB
2017-08-02 18:53:18.790010: I tensorflow/core/common_runtime/gpu/gpu_device.cc:961] DMA: 0 
2017-08-02 18:53:18.790016: I tensorflow/core/common_runtime/gpu/gpu_device.cc:971] 0:   Y 
2017-08-02 18:53:18.790027: I tensorflow/core/common_runtime/gpu/gpu_device.cc:1030] Creating TensorFlow device (/gpu:0) -> (device: 0, name: GeForce GTX TITAN X, pci bus id: 0000:01:00.0)

{% endhighlight %}




    <Tensor Group:1 shape=unknown dtype=Any>



### Train


We use normal minibatch training with Adam.
We do use relatively large minibatches, as that gets best performance advantage on GPU,
by minimizing memory transfers.
A more advanced implementation might do a the batching within Tensorflow,
rather than batching outside tensorflow and invoking it via `run`.

**Input:**

{% highlight julia %}
traindata = (flatten_images(MNIST.traintensor()), onehot_encode_labels(MNIST.trainlabels()))
run(sess, global_variables_initializer())


basic_train_loss = Float64[]
@showprogress for epoch in 1:100
    epoch_loss = Float64[]
    for (batch_x, batch_y) in eachbatch(traindata, 1000, (ObsDim.Last(), ObsDim.First()))
        loss_o, _ = run(sess, (loss, optimizer), Dict(X=>batch_x', Y=>batch_y))
        push!(epoch_loss, loss_o)
    end
    push!(basic_train_loss, mean(epoch_loss))
    #println("Epoch $epoch: $(train_loss[end])")
end
{% endhighlight %}

**Output:**

{% highlight plaintext %}
Progress: 100%|█████████████████████████████████████████| Time: 0:01:25

{% endhighlight %}

**Input:**

{% highlight julia %}
plot(basic_train_loss, label="training loss")
{% endhighlight %}

**Output:**




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
39.3701,368.504 592.126,368.504 592.126,7.87402 39.3701,7.87402 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip02">
    <rect x="39" y="7" width="554" height="362"/>
  </clipPath>
</defs>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  173.372,363.094 173.372,13.2835 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  312.956,363.094 312.956,13.2835 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  452.541,363.094 452.541,13.2835 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  592.126,363.094 592.126,13.2835 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  47.6614,293.95 583.835,293.95 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  47.6614,218.969 583.835,218.969 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  47.6614,143.988 583.835,143.988 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  47.6614,69.0065 583.835,69.0065 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,368.504 592.126,368.504 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  173.372,368.504 173.372,363.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  312.956,368.504 312.956,363.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  452.541,368.504 452.541,363.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  592.126,368.504 592.126,363.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,368.504 39.3701,7.87402 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,293.95 47.6614,293.95 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,218.969 47.6614,218.969 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,143.988 47.6614,143.988 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,69.0065 47.6614,69.0065 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 173.372, 382.304)" x="173.372" y="382.304">25</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 312.956, 382.304)" x="312.956" y="382.304">50</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 452.541, 382.304)" x="452.541" y="382.304">75</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 592.126, 382.304)" x="592.126" y="382.304">100</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 33.3701, 298.45)" x="33.3701" y="298.45">0.25</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 33.3701, 223.469)" x="33.3701" y="223.469">0.50</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 33.3701, 148.488)" x="33.3701" y="148.488">0.75</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 33.3701, 73.5065)" x="33.3701" y="73.5065">1.00</text>
</g>
<polyline clip-path="url(#clip02)" style="stroke:#009af9; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,7.87402 44.9535,247.655 50.5369,274.648 56.1203,285.296 61.7037,292.448 67.287,298.371 72.8704,303.631 78.4538,308.366 84.0372,312.632 89.6206,316.482 
  95.204,319.972 100.787,323.148 106.371,326.05 111.954,328.713 117.538,331.164 123.121,333.43 128.704,335.528 134.288,337.477 139.871,339.289 145.455,340.976 
  151.038,342.55 156.621,344.019 162.205,345.393 167.788,346.679 173.372,347.886 178.955,349.018 184.538,350.084 190.122,351.088 195.705,352.034 201.288,352.927 
  206.872,353.771 212.455,354.57 218.039,355.325 223.622,356.042 229.205,356.722 234.789,357.369 240.372,357.985 245.956,358.573 251.539,359.134 257.122,359.669 
  262.706,360.179 268.289,360.663 273.873,361.123 279.456,361.557 285.039,361.967 290.623,362.352 296.206,362.715 301.79,363.056 307.373,363.376 312.956,363.677 
  318.54,363.959 324.123,364.225 329.707,364.475 335.29,364.71 340.873,364.932 346.457,365.142 352.04,365.34 357.623,365.527 363.207,365.704 368.79,365.872 
  374.374,366.03 379.957,366.18 385.54,366.321 391.124,366.455 396.707,366.581 402.291,366.701 407.874,366.814 413.457,366.921 419.041,367.023 424.624,367.119 
  430.208,367.211 435.791,367.299 441.374,367.383 446.958,367.463 452.541,367.539 458.125,367.612 463.708,367.681 469.291,367.745 474.875,367.806 480.458,367.863 
  486.042,367.916 491.625,367.965 497.208,368.01 502.792,368.053 508.375,368.093 513.958,368.13 519.542,368.166 525.125,368.199 530.709,368.231 536.292,368.262 
  541.875,368.291 547.459,368.319 553.042,368.346 558.626,368.372 564.209,368.396 569.792,368.42 575.376,368.442 580.959,368.464 586.543,368.484 592.126,368.504 
  
  "/>
<polygon clip-path="url(#clip00)" points="
450.896,58.994 574.126,58.994 574.126,28.754 450.896,28.754 
  " fill="#ffffff" fill-opacity="1"/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  450.896,58.994 574.126,58.994 574.126,28.754 450.896,28.754 450.896,58.994 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#009af9; stroke-width:1; stroke-opacity:1; fill:none" points="
  456.896,43.874 492.896,43.874 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 498.896, 48.374)" x="498.896" y="48.374">training loss</text>
</g>
</svg>




### Test

**Input:**

{% highlight julia %}
testdata_x = flatten_images(MNIST.testtensor())
testdata_y = onehot_encode_labels(MNIST.testlabels())

y_probs_o = run(sess, Y_probs, Dict(X=>testdata_x'))
acc = mean(mapslices(indmax, testdata_y, 2) .== mapslices(indmax, y_probs_o, 2) )

println("Error Rate: $((1-acc)*100)%")
{% endhighlight %}

**Output:**

{% highlight plaintext %}
Error Rate: 1.9299999999999984%

{% endhighlight %}

## Advanced MNIST classifier

Here we will use more advanced TensorFlow features, like `indmax`,
and also a more advanced network.

**Input:**

{% highlight julia %}
load("Intro\ to\ Machine\ Learning\ with\ Tensorflow.jl/mnist-advanced.png")
{% endhighlight %}

**Output:**




![png]({{site.url}}/posts_assets/Intro to Machine Learning with TensorFlow.jl_files/Intro to Machine Learning with TensorFlow.jl_17_0.png)



**Input:**

{% highlight julia %}
sess = Session(Graph())

# Network Definition
begin
    X = placeholder(Float32, shape=[-1, 28*28])
    Y = placeholder(Float32, shape=[-1])
    KeepProb = placeholder(Float32, shape=[])
    
    # Network parameters
    hl_sizes = [512, 512, 512]
    activation_functions = Vector{Function}(size(hl_sizes))
    activation_functions[1:end-1]=z->nn.dropout(nn.relu(z), KeepProb)
    activation_functions[end] = identity #Last function should be idenity as we need the logits

    Zs = [X]
    for (ii,(hlsize, actfun)) in enumerate(zip(hl_sizes, activation_functions))
        Wii = get_variable("W_$ii", [get_shape(Zs[end], 2), hlsize], Float32)
        bii = get_variable("b_$ii", [hlsize], Float32)
        Zii = actfun(Zs[end]*Wii + bii)
        push!(Zs, Zii)
    end
    
    Y_probs = nn.softmax(Zs[end])
    Y_preds = indmax(Y_probs,2)-1 # Minus 1, to offset 1 based indexing

    losses = nn.sparse_softmax_cross_entropy_with_logits(;logits=Zs[end], labels=Y+1) # Plus 1, to offset 1 based indexing 
    #This loss function takes the unscaled logits, and the numerical labels
    loss = reduce_mean(losses)
    optimizer = train.minimize(train.AdamOptimizer(), loss)
end

{% endhighlight %}

**Output:**

{% highlight plaintext %}
2017-08-02 19:27:57.180945: I tensorflow/core/common_runtime/gpu/gpu_device.cc:1030] Creating TensorFlow device (/gpu:0) -> (device: 0, name: GeForce GTX TITAN X, pci bus id: 0000:01:00.0)

{% endhighlight %}




    <Tensor Group:1 shape=unknown dtype=Any>



### Train

**Input:**

{% highlight julia %}
traindata_x = flatten_images(MNIST.traintensor())
normer = fit(FeatureNormalizer, traindata_x)
predict!(normer, traindata_x); # perhaps oddly, in current version of MLDataUtils the Normalizer commands to normalize is `predict`

traindata_y = Int.(MNIST.trainlabels());

{% endhighlight %}

**Input:**

{% highlight julia %}
run(sess, global_variables_initializer())
adv_train_loss = Float64[]
@showprogress for epoch in 1:100
    epoch_loss = Float64[]
    for (batch_x, batch_y) in eachbatch((traindata_x, traindata_y), 1000, ObsDim.Last())
        loss_o, _ = run(sess, (loss, optimizer), Dict(X=>batch_x', Y=>batch_y, KeepProb=>0.5f0))
        push!(epoch_loss, loss_o)
    end
    push!(adv_train_loss, mean(epoch_loss))
    #println("Epoch $epoch: $(train_loss[end])")
end
{% endhighlight %}

**Output:**

{% highlight plaintext %}
Progress: 100%|█████████████████████████████████████████| Time: 0:01:10

{% endhighlight %}

**Input:**

{% highlight julia %}
plot([basic_train_loss, adv_train_loss], label=["basic", "advanced"])
{% endhighlight %}

**Output:**




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
39.3701,368.504 592.126,368.504 592.126,7.87402 39.3701,7.87402 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip02">
    <rect x="39" y="7" width="554" height="362"/>
  </clipPath>
</defs>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  173.372,363.094 173.372,13.2835 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  312.956,363.094 312.956,13.2835 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  452.541,363.094 452.541,13.2835 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  592.126,363.094 592.126,13.2835 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  47.6614,235.328 583.835,235.328 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  47.6614,101.772 583.835,101.772 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,368.504 592.126,368.504 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  173.372,368.504 173.372,363.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  312.956,368.504 312.956,363.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  452.541,368.504 452.541,363.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  592.126,368.504 592.126,363.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,368.504 39.3701,7.87402 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,235.328 47.6614,235.328 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,101.772 47.6614,101.772 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 173.372, 382.304)" x="173.372" y="382.304">25</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 312.956, 382.304)" x="312.956" y="382.304">50</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 452.541, 382.304)" x="452.541" y="382.304">75</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 592.126, 382.304)" x="592.126" y="382.304">100</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 33.3701, 239.828)" x="33.3701" y="239.828">0.5</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 33.3701, 106.272)" x="33.3701" y="106.272">1.0</text>
</g>
<polyline clip-path="url(#clip02)" style="stroke:#009af9; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,47.3281 44.9535,260.876 50.5369,284.916 56.1203,294.399 61.7037,300.768 67.287,306.044 72.8704,310.728 78.4538,314.945 84.0372,318.744 89.6206,322.174 
  95.204,325.282 100.787,328.11 106.371,330.695 111.954,333.066 117.538,335.249 123.121,337.267 128.704,339.136 134.288,340.871 139.871,342.485 145.455,343.988 
  151.038,345.389 156.621,346.698 162.205,347.922 167.788,349.067 173.372,350.141 178.955,351.15 184.538,352.099 190.122,352.993 195.705,353.836 201.288,354.632 
  206.872,355.383 212.455,356.094 218.039,356.767 223.622,357.405 229.205,358.011 234.789,358.587 240.372,359.136 245.956,359.659 251.539,360.159 257.122,360.636 
  262.706,361.09 268.289,361.521 273.873,361.93 279.456,362.317 285.039,362.682 290.623,363.025 296.206,363.348 301.79,363.652 307.373,363.937 312.956,364.205 
  318.54,364.456 324.123,364.693 329.707,364.916 335.29,365.125 340.873,365.323 346.457,365.51 352.04,365.686 357.623,365.853 363.207,366.01 368.79,366.16 
  374.374,366.301 379.957,366.434 385.54,366.56 391.124,366.679 396.707,366.792 402.291,366.898 407.874,366.999 413.457,367.094 419.041,367.185 424.624,367.271 
  430.208,367.353 435.791,367.431 441.374,367.506 446.958,367.577 452.541,367.645 458.125,367.709 463.708,367.771 469.291,367.828 474.875,367.883 480.458,367.933 
  486.042,367.98 491.625,368.024 497.208,368.064 502.792,368.102 508.375,368.138 513.958,368.171 519.542,368.203 525.125,368.233 530.709,368.261 536.292,368.289 
  541.875,368.315 547.459,368.339 553.042,368.363 558.626,368.386 564.209,368.408 569.792,368.429 575.376,368.449 580.959,368.468 586.543,368.487 592.126,368.504 
  
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#e26f46; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,7.87402 44.9535,292.962 50.5369,313.504 56.1203,323.775 61.7037,329.766 67.287,334.976 72.8704,338.456 78.4538,341.24 84.0372,342.693 89.6206,345.277 
  95.204,346.617 100.787,347.864 106.371,349.952 111.954,348.806 117.538,351.698 123.121,351.144 128.704,351.68 134.288,353.022 139.871,353.428 145.455,354.875 
  151.038,355.659 156.621,355.643 162.205,356.292 167.788,357.189 173.372,358.437 178.955,357.461 184.538,354.46 190.122,357.353 195.705,357.619 201.288,358.24 
  206.872,358.385 212.455,358.782 218.039,358.914 223.622,359.116 229.205,359.91 234.789,359.861 240.372,360.151 245.956,359.375 251.539,359.823 257.122,360.956 
  262.706,360.003 268.289,361.29 273.873,361.079 279.456,361.285 285.039,360.97 290.623,361.588 296.206,361.284 301.79,361.694 307.373,360.426 312.956,362.038 
  318.54,362.103 324.123,360.892 329.707,361.191 335.29,360.992 340.873,361.62 346.457,362.145 352.04,361.957 357.623,362.199 363.207,361.542 368.79,362.554 
  374.374,362.236 379.957,362.782 385.54,362.91 391.124,363.274 396.707,361.938 402.291,362.293 407.874,362.045 413.457,362.987 419.041,362.965 424.624,362.474 
  430.208,362.855 435.791,363.227 441.374,362.24 446.958,362.556 452.541,363.099 458.125,362.833 463.708,362.635 469.291,363.005 474.875,362.198 480.458,362.781 
  486.042,362.413 491.625,362.455 497.208,363.585 502.792,363.919 508.375,363.298 513.958,361.991 519.542,362.744 525.125,362.635 530.709,362.617 536.292,362.241 
  541.875,362.714 547.459,362.822 553.042,363.254 558.626,363.462 564.209,364.073 569.792,363.994 575.376,363.412 580.959,363.367 586.543,363.635 592.126,363.718 
  
  "/>
<polygon clip-path="url(#clip00)" points="
462.736,74.114 574.126,74.114 574.126,28.754 462.736,28.754 
  " fill="#ffffff" fill-opacity="1"/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  462.736,74.114 574.126,74.114 574.126,28.754 462.736,28.754 462.736,74.114 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#009af9; stroke-width:1; stroke-opacity:1; fill:none" points="
  468.736,43.874 504.736,43.874 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 510.736, 48.374)" x="510.736" y="48.374">basic</text>
</g>
<polyline clip-path="url(#clip00)" style="stroke:#e26f46; stroke-width:1; stroke-opacity:1; fill:none" points="
  468.736,58.994 504.736,58.994 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 510.736, 63.494)" x="510.736" y="63.494">advanced</text>
</g>
</svg>




### Test

**Input:**

{% highlight julia %}
testdata_x = predict!(normer, flatten_images(MNIST.testtensor()))
testdata_y = Int.(MNIST.testlabels());

y_preds_o = run(sess, Y_preds, Dict(X=>testdata_x', KeepProb=>1.0f0))
acc = mean(testdata_y .== y_preds_o )

println("Error Rate: $((1-acc)*100)%")
{% endhighlight %}

**Output:**

{% highlight plaintext %}
Error Rate: 1.770000000000005%

{% endhighlight %}

It can be seen that overall all the extra stuff done in the advanced model did not gain much.
The margin is small enough that it can be attributed to in part to luck -- repeating it can do better or worse depending on the random initialisations.
Classifying MNIST is perhaps too simpler problem for deep techneques to pay off.


# Bottle-necked Autoencoder

An autoencoder is a neural network designed to recreate its inputs.
There are many varieties, include RBMs, DBNs, SDAs, mSDAs, VAEs.
This is one of the simplest being based on just a feedforward neural network.

The network narrows into to a very small central layer -- in this case just 2 neurons,
before exampanding back to the full size.
It is sometimes called a Hour-glass, or Wine-glass autoencoder to describe this shape.


**Input:**

{% highlight julia %}
load("Intro\ to\ Machine\ Learning\ with\ Tensorflow.jl/autoencoder.png")
{% endhighlight %}

**Output:**




![png]({{site.url}}/posts_assets/Intro to Machine Learning with TensorFlow.jl_files/Intro to Machine Learning with TensorFlow.jl_28_0.png)



**Input:**

{% highlight julia %}
sess = Session(Graph())

# Network Definition

begin
    X = placeholder(Float32, shape=[-1, 28*28])
    
    # Network parameters
    hl_sizes = [512, 128, 64, 2, 64, 128, 512, 28*28]
    activation_functions = Vector{Function}(size(hl_sizes))
    activation_functions[1:end-1] = x -> 0.01x + nn.relu6(x)
        # Neither sigmoid, nor relu work anywhere near as well here
        # relu6 works sometimes, but the hidden neurons die too often
        # So we define a leaky ReLU6 as above
    activation_functions[end] = nn.sigmoid #Between 0 and 1


    Zs = [X]
    for (ii,(hlsize, actfun)) in enumerate(zip(hl_sizes, activation_functions))
        Wii = get_variable("W_$ii", [get_shape(Zs[end], 2), hlsize], Float32)
        bii = get_variable("b_$ii", [hlsize], Float32)
        Zii = actfun(Zs[end]*Wii + bii)
        push!(Zs, Zii)
    end
    
    
    Z_code = Zs[end÷2 + 1] # A name for the coding layer
    has_died = reduce_any(reduce_all(Z_code.==0f0, axis=2))
    
    losses = 0.5(Zs[end]-X)^2
    
    loss = reduce_mean(losses)
    optimizer = train.minimize(train.AdamOptimizer(), loss)
end
{% endhighlight %}

**Output:**

{% highlight plaintext %}
2017-08-02 19:52:56.573001: W tensorflow/core/platform/cpu_feature_guard.cc:45] The TensorFlow library wasn't compiled to use SSE4.1 instructions, but these are available on your machine and could speed up CPU computations.
2017-08-02 19:52:56.573045: W tensorflow/core/platform/cpu_feature_guard.cc:45] The TensorFlow library wasn't compiled to use SSE4.2 instructions, but these are available on your machine and could speed up CPU computations.
2017-08-02 19:52:56.573054: W tensorflow/core/platform/cpu_feature_guard.cc:45] The TensorFlow library wasn't compiled to use AVX instructions, but these are available on your machine and could speed up CPU computations.
2017-08-02 19:52:56.810042: I tensorflow/stream_executor/cuda/cuda_gpu_executor.cc:893] successful NUMA node read from SysFS had negative value (-1), but there must be at least one NUMA node, so returning NUMA node zero
2017-08-02 19:52:56.810561: I tensorflow/core/common_runtime/gpu/gpu_device.cc:940] Found device 0 with properties: 
name: GeForce GTX TITAN X
major: 5 minor: 2 memoryClockRate (GHz) 1.076
pciBusID 0000:01:00.0
Total memory: 11.91GiB
Free memory: 11.42GiB
2017-08-02 19:52:56.810575: I tensorflow/core/common_runtime/gpu/gpu_device.cc:961] DMA: 0 
2017-08-02 19:52:56.810584: I tensorflow/core/common_runtime/gpu/gpu_device.cc:971] 0:   Y 
2017-08-02 19:52:56.810602: I tensorflow/core/common_runtime/gpu/gpu_device.cc:1030] Creating TensorFlow device (/gpu:0) -> (device: 0, name: GeForce GTX TITAN X, pci bus id: 0000:01:00.0)

{% endhighlight %}




    <Tensor Group:1 shape=unknown dtype=Any>



The choice of activation function here, is (as mentioned in the comments) a bit special.
On this particular problem, as a deep network, sigmoid was not going well presumably because of the exploding/vanishing gradient issue that normally cases it to not work out (though I did not check).

Switching to ReLU did not help, though I now suspect I didn't give it enough tries.
ReLU6 worked great the first few tries, but coming back to it later,
and I found I couldn't get it to train because one or both of the hidden units would die,
which I did see the first times I trained it but not as commonly.

The trick to make this never happen was to allow the units to turn themselves back on.
This is done by providing a non-zero gradient for the off-states.
A leaky RELU6 unit.
Mathematically it is given by 
$$\varphi(z)=\begin{cases}
0.01z+6 && 6<z \\
1.01z && 0 \le z \le 6 \\
0.01z && z < 0
\end{cases}$$

## Training

**Input:**

{% highlight julia %}
train_images = flatten_images(MNIST.traintensor())
test_images = flatten_images(MNIST.testtensor());
{% endhighlight %}

**Input:**

{% highlight julia %}
run(sess, global_variables_initializer())
auto_loss = Float64[]
@showprogress for epoch in 1:75
    epoch_loss = Float64[]
    for batch_x in eachbatch(train_images, 1_000, ObsDim.Last())
        loss_o, _ = run(sess, (loss, optimizer), Dict(X=>batch_x'))
        push!(epoch_loss, loss_o)
    end
    push!(auto_loss, mean(epoch_loss))
    #println("Epoch $epoch loss: $(auto_loss[end])")
    
    ### Check to see if it died
    if run(sess, has_died, Dict(X=>train_images'))
        error("Neuron in hidden layer has died, must reinitialize.")
    end
end

{% endhighlight %}

**Output:**

{% highlight plaintext %}
Progress: 100%|█████████████████████████████████████████| Time: 0:01:51

{% endhighlight %}

**Input:**

{% highlight julia %}
plot([auto_loss], label="Autoencoder Loss")
{% endhighlight %}

**Output:**




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
39.3701,368.504 592.126,368.504 592.126,7.87402 39.3701,7.87402 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip02">
    <rect x="39" y="7" width="554" height="362"/>
  </clipPath>
</defs>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  181.294,363.094 181.294,13.2835 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  330.687,363.094 330.687,13.2835 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  480.081,363.094 480.081,13.2835 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  47.6614,359.821 583.835,359.821 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  47.6614,207.937 583.835,207.937 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  47.6614,56.0531 583.835,56.0531 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,368.504 592.126,368.504 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  181.294,368.504 181.294,363.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  330.687,368.504 330.687,363.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  480.081,368.504 480.081,363.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,368.504 39.3701,7.87402 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,359.821 47.6614,359.821 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,207.937 47.6614,207.937 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,56.0531 47.6614,56.0531 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 181.294, 382.304)" x="181.294" y="382.304">20</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 330.687, 382.304)" x="330.687" y="382.304">40</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 480.081, 382.304)" x="480.081" y="382.304">60</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 33.3701, 364.321)" x="33.3701" y="364.321">0.02</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 33.3701, 212.437)" x="33.3701" y="212.437">0.04</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 33.3701, 60.5531)" x="33.3701" y="60.5531">0.06</text>
</g>
<polyline clip-path="url(#clip02)" style="stroke:#009af9; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,7.87402 46.8398,260.674 54.3094,267.93 61.7791,271.81 69.2488,278.343 76.7185,282.005 84.1881,283.083 91.6578,283.617 99.1275,283.94 106.597,284.222 
  114.067,284.557 121.536,285.107 129.006,285.72 136.476,286.461 143.946,287.535 151.415,289.475 158.885,292.618 166.355,294.952 173.824,298.302 181.294,301.181 
  188.764,303.369 196.233,304.02 203.703,305.49 211.173,306.592 218.642,307.361 226.112,308.952 233.582,312.38 241.051,317.447 248.521,323.025 255.991,328.188 
  263.46,331.822 270.93,335.591 278.4,338.634 285.869,341.112 293.339,343.369 300.809,345.181 308.278,347.111 315.748,348.239 323.218,349.581 330.687,350.755 
  338.157,351.971 345.627,352.766 353.096,353.626 360.566,354.283 368.036,355.516 375.505,356.279 382.975,356.746 390.445,357.561 397.914,357.959 405.384,358.751 
  412.854,358.626 420.323,359.476 427.793,360.082 435.263,360.375 442.732,361.444 450.202,362.048 457.672,362.451 465.142,362.909 472.611,363.413 480.081,363.777 
  487.551,363.982 495.02,364.536 502.49,364.912 509.96,365.33 517.429,365.378 524.899,365.639 532.369,365.885 539.838,366.026 547.308,365.797 554.778,366.892 
  562.247,367.144 569.717,367.655 577.187,368.09 584.656,368.273 592.126,368.504 
  "/>
<polygon clip-path="url(#clip00)" points="
418.6,58.994 574.126,58.994 574.126,28.754 418.6,28.754 
  " fill="#ffffff" fill-opacity="1"/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  418.6,58.994 574.126,58.994 574.126,28.754 418.6,28.754 418.6,58.994 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#009af9; stroke-width:1; stroke-opacity:1; fill:none" points="
  424.6,43.874 460.6,43.874 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 466.6, 48.374)" x="466.6" y="48.374">Autoencoder Loss</text>
</g>
</svg>




**Input:**

{% highlight julia %}
function reconstruct(img::Vector)
    run(sess, Zs[end], Dict(X=>reshape(img, (1,28*28))))[:]
end
{% endhighlight %}

**Output:**




    reconstruct (generic function with 1 method)



**Input:**

{% highlight julia %}
id = 120
heatmap([one_image(train_images[:,id]) one_image(reconstruct(train_images[:,id]))])
{% endhighlight %}

**Output:**




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
39.3701,368.504 592.126,368.504 592.126,7.87402 39.3701,7.87402 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip02">
    <rect x="39" y="7" width="494" height="362"/>
  </clipPath>
</defs>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  199.516,363.094 199.516,13.2835 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  363.768,363.094 363.768,13.2835 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  528.02,363.094 528.02,13.2835 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  46.7614,254.304 524.735,254.304 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  46.7614,134.094 524.735,134.094 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  46.7614,13.8845 524.735,13.8845 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,368.504 532.126,368.504 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  199.516,368.504 199.516,363.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  363.768,368.504 363.768,363.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  528.02,368.504 528.02,363.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,368.504 39.3701,7.87402 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,254.304 46.7614,254.304 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,134.094 46.7614,134.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,13.8845 46.7614,13.8845 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 199.516, 382.304)" x="199.516" y="382.304">20</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 363.768, 382.304)" x="363.768" y="382.304">40</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 528.02, 382.304)" x="528.02" y="382.304">60</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 33.3701, 258.804)" x="33.3701" y="258.804">10</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 33.3701, 138.594)" x="33.3701" y="138.594">20</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 33.3701, 18.3845)" x="33.3701" y="18.3845">30</text>
</g>
<g clip-path="url(#clip02)">
<image width="493" height="361" xlink:href="data:;base64,
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
AAAASUVORK5CYII=
" transform="translate(39, 8)"/>
</g>
<defs>
  <clipPath id="clip03">
    <rect x="544" y="7" width="19" height="362"/>
  </clipPath>
</defs>
<g clip-path="url(#clip03)">
<image width="18" height="361" xlink:href="data:;base64,
iVBORw0KGgoAAAANSUhEUgAAABIAAAFpCAYAAACRXHjhAAACEUlEQVR4nO3c0W3EMAyDYafI/lN0
y17jjpCXD8UPwR6AMElR8hkXX5/ney+wvgTIWmvdz/4YoI2AHLX9zKVWc42JPVgjR22pynZAR6O3
Jan9ICAVkaJGiNq1fwmQpGZ2dF8IKEhtIdcmazSa2mOA1I6SGvWoIdcUtdn2G7GD9rspMlejov3H
tX8EIvdQUqMd00jab8Tu1dFgjSS1GhCK2mSNitRMQugN+2WAoP1mR/IammlUo6Z2NFsjg8U0KtrP
2sg27IIdUgENruxg+ndNo2T6c6FVBenSn2tsueaftH9s+mFl96jFXDsReV9Far3KrhXk/eTmWk6j
IrUaUFCjZy61HNBgjeQfvWPUkhrFjn6D7R9MbbRGay41N/sJTnGu9Y41DyrIyRo5agSmSa3nmqps
1iGDja2WftnYENBJ/ztQMf0ICB79zCoe/QhMkprq2cmTvwLKUduM2uTGpoAG229wio1tsEaQWq2y
4ThCQL0fNWdkvwMVT2w1oMkaGZxkzz72vwJt9C1MkhoC6s21ydRcY0PfQaodyQtNRK3Y/MdSy/Xs
YPpdaHtzzYWW2V/TyFX2sf8VaKNvhYsaXT1q6MEJBSRDq6hdLCI1jZj9xdCi14agRrW3xkan/9j/
smCHRO/NBKlt9WpVr0O6iBz731bQtcmV7ajlenbNtXvn3s9m1FbuJmLVGhvbUdL+udQQ0B+p8+fh
sEs94QAAAABJRU5ErkJggg==
" transform="translate(544, 8)"/>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 371.917)" x="568.126" y="371.917">0</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 335.854)" x="568.126" y="335.854">0.1</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 299.791)" x="568.126" y="299.791">0.2</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 263.728)" x="568.126" y="263.728">0.3</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 227.665)" x="568.126" y="227.665">0.4</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 191.602)" x="568.126" y="191.602">0.5</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 155.539)" x="568.126" y="155.539">0.6</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 119.476)" x="568.126" y="119.476">0.7</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 83.4128)" x="568.126" y="83.4128">0.8</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 47.3498)" x="568.126" y="47.3498">0.9</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 11.2868)" x="568.126" y="11.2868">1.0</text>
</g>
</svg>




**Input:**

{% highlight julia %}
id = 1
heatmap([one_image(test_images[:,id]) one_image(reconstruct(test_images[:,id]))])
{% endhighlight %}

**Output:**




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
39.3701,368.504 592.126,368.504 592.126,7.87402 39.3701,7.87402 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip02">
    <rect x="39" y="7" width="494" height="362"/>
  </clipPath>
</defs>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  199.516,363.094 199.516,13.2835 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  363.768,363.094 363.768,13.2835 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  528.02,363.094 528.02,13.2835 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  46.7614,254.304 524.735,254.304 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  46.7614,134.094 524.735,134.094 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  46.7614,13.8845 524.735,13.8845 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,368.504 532.126,368.504 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  199.516,368.504 199.516,363.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  363.768,368.504 363.768,363.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  528.02,368.504 528.02,363.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,368.504 39.3701,7.87402 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,254.304 46.7614,254.304 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,134.094 46.7614,134.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,13.8845 46.7614,13.8845 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 199.516, 382.304)" x="199.516" y="382.304">20</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 363.768, 382.304)" x="363.768" y="382.304">40</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 528.02, 382.304)" x="528.02" y="382.304">60</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 33.3701, 258.804)" x="33.3701" y="258.804">10</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 33.3701, 138.594)" x="33.3701" y="138.594">20</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 33.3701, 18.3845)" x="33.3701" y="18.3845">30</text>
</g>
<g clip-path="url(#clip02)">
<image width="493" height="361" xlink:href="data:;base64,
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
" transform="translate(39, 8)"/>
</g>
<defs>
  <clipPath id="clip03">
    <rect x="544" y="7" width="19" height="362"/>
  </clipPath>
</defs>
<g clip-path="url(#clip03)">
<image width="18" height="361" xlink:href="data:;base64,
iVBORw0KGgoAAAANSUhEUgAAABIAAAFpCAYAAACRXHjhAAACEUlEQVR4nO3c0W3EMAyDYafI/lN0
y17jjpCXD8UPwR6AMElR8hkXX5/ney+wvgTIWmvdz/4YoI2AHLX9zKVWc42JPVgjR22pynZAR6O3
Jan9ICAVkaJGiNq1fwmQpGZ2dF8IKEhtIdcmazSa2mOA1I6SGvWoIdcUtdn2G7GD9rspMlejov3H
tX8EIvdQUqMd00jab8Tu1dFgjSS1GhCK2mSNitRMQugN+2WAoP1mR/IammlUo6Z2NFsjg8U0KtrP
2sg27IIdUgENruxg+ndNo2T6c6FVBenSn2tsueaftH9s+mFl96jFXDsReV9Far3KrhXk/eTmWk6j
IrUaUFCjZy61HNBgjeQfvWPUkhrFjn6D7R9MbbRGay41N/sJTnGu9Y41DyrIyRo5agSmSa3nmqps
1iGDja2WftnYENBJ/ztQMf0ICB79zCoe/QhMkprq2cmTvwLKUduM2uTGpoAG229wio1tsEaQWq2y
4ThCQL0fNWdkvwMVT2w1oMkaGZxkzz72vwJt9C1MkhoC6s21ydRcY0PfQaodyQtNRK3Y/MdSy/Xs
YPpdaHtzzYWW2V/TyFX2sf8VaKNvhYsaXT1q6MEJBSRDq6hdLCI1jZj9xdCi14agRrW3xkan/9j/
smCHRO/NBKlt9WpVr0O6iBz731bQtcmV7ajlenbNtXvn3s9m1FbuJmLVGhvbUdL+udQQ0B+p8+fh
sEs94QAAAABJRU5ErkJggg==
" transform="translate(544, 8)"/>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 371.917)" x="568.126" y="371.917">0</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 335.854)" x="568.126" y="335.854">0.1</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 299.791)" x="568.126" y="299.791">0.2</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 263.728)" x="568.126" y="263.728">0.3</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 227.665)" x="568.126" y="227.665">0.4</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 191.602)" x="568.126" y="191.602">0.5</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 155.539)" x="568.126" y="155.539">0.6</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 119.476)" x="568.126" y="119.476">0.7</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 83.4128)" x="568.126" y="83.4128">0.8</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 47.3498)" x="568.126" y="47.3498">0.9</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 11.2868)" x="568.126" y="11.2868">1.0</text>
</g>
</svg>




## Visualising similarity 
One of the key uses of an autoencoder such as this is to project from a the high dimentional space of the inputs, to the low dimentional space of the code layer.

**Input:**

{% highlight julia %}
function scatter_image(images, res)
    canvas = ones(res, res)
    
    codes = run(sess, Z_code, Dict(X=>images'))
    codes = (codes .- minimum(codes))./(maximum(codes)-minimum(codes))
    @assert(minimum(codes) >= 0.0)
    @assert(maximum(codes) <= 1.0)
    
    function target_area(code)
        central_res = res-frames_image_res-1
        border_offset = frames_image_res/2 + 1
        x,y = code*central_res + border_offset
        
        get_pos(v) = round(Int, v-frames_image_res/2)
        x_min = get_pos(x)
        x_max = x_min + frames_image_res-1
        y_min =  get_pos(y)
        y_max = y_min + frames_image_res-1
        
        @view canvas[x_min:x_max, y_min:y_max]
    end
    
    for ii in 1:size(codes, 1)
        code = codes[ii,:]
        img = images[:,ii]
        area = target_area(code)        
        any(area.<1) && continue # Don't draw over anything
        area[:] = one_image(img)
    end
    canvas
end
heatmap(scatter_image(test_images, 700))
{% endhighlight %}

**Output:**




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
39.3701,368.504 592.126,368.504 592.126,7.87402 39.3701,7.87402 
  " fill="#ffffff" fill-opacity="1"/>
<defs>
  <clipPath id="clip02">
    <rect x="39" y="7" width="494" height="362"/>
  </clipPath>
</defs>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  179.806,363.094 179.806,13.2835 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  320.593,363.094 320.593,13.2835 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  461.38,363.094 461.38,13.2835 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  46.7614,265.724 524.735,265.724 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  46.7614,162.687 524.735,162.687 
  "/>
<polyline clip-path="url(#clip02)" style="stroke:#000000; stroke-width:1; stroke-opacity:0.5; fill:none" stroke-dasharray="1, 2" points="
  46.7614,59.6502 524.735,59.6502 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,368.504 532.126,368.504 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  179.806,368.504 179.806,363.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  320.593,368.504 320.593,363.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  461.38,368.504 461.38,363.094 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,368.504 39.3701,7.87402 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,265.724 46.7614,265.724 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,162.687 46.7614,162.687 
  "/>
<polyline clip-path="url(#clip00)" style="stroke:#000000; stroke-width:1; stroke-opacity:1; fill:none" points="
  39.3701,59.6502 46.7614,59.6502 
  "/>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 179.806, 382.304)" x="179.806" y="382.304">200</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 320.593, 382.304)" x="320.593" y="382.304">400</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:middle;" transform="rotate(0, 461.38, 382.304)" x="461.38" y="382.304">600</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 33.3701, 270.224)" x="33.3701" y="270.224">200</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 33.3701, 167.187)" x="33.3701" y="167.187">400</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:end;" transform="rotate(0, 33.3701, 64.1502)" x="33.3701" y="64.1502">600</text>
</g>
<g clip-path="url(#clip02)">
<image width="493" height="361" xlink:href="data:;base64,
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
" transform="translate(39, 8)"/>
</g>
<defs>
  <clipPath id="clip03">
    <rect x="544" y="7" width="19" height="362"/>
  </clipPath>
</defs>
<g clip-path="url(#clip03)">
<image width="18" height="361" xlink:href="data:;base64,
iVBORw0KGgoAAAANSUhEUgAAABIAAAFpCAYAAACRXHjhAAACEUlEQVR4nO3c0W3EMAyDYafI/lN0
y17jjpCXD8UPwR6AMElR8hkXX5/ney+wvgTIWmvdz/4YoI2AHLX9zKVWc42JPVgjR22pynZAR6O3
Jan9ICAVkaJGiNq1fwmQpGZ2dF8IKEhtIdcmazSa2mOA1I6SGvWoIdcUtdn2G7GD9rspMlejov3H
tX8EIvdQUqMd00jab8Tu1dFgjSS1GhCK2mSNitRMQugN+2WAoP1mR/IammlUo6Z2NFsjg8U0KtrP
2sg27IIdUgENruxg+ndNo2T6c6FVBenSn2tsueaftH9s+mFl96jFXDsReV9Far3KrhXk/eTmWk6j
IrUaUFCjZy61HNBgjeQfvWPUkhrFjn6D7R9MbbRGay41N/sJTnGu9Y41DyrIyRo5agSmSa3nmqps
1iGDja2WftnYENBJ/ztQMf0ICB79zCoe/QhMkprq2cmTvwLKUduM2uTGpoAG229wio1tsEaQWq2y
4ThCQL0fNWdkvwMVT2w1oMkaGZxkzz72vwJt9C1MkhoC6s21ydRcY0PfQaodyQtNRK3Y/MdSy/Xs
YPpdaHtzzYWW2V/TyFX2sf8VaKNvhYsaXT1q6MEJBSRDq6hdLCI1jZj9xdCi14agRrW3xkan/9j/
smCHRO/NBKlt9WpVr0O6iBz731bQtcmV7ajlenbNtXvn3s9m1FbuJmLVGhvbUdL+udQQ0B+p8+fh
sEs94QAAAABJRU5ErkJggg==
" transform="translate(544, 8)"/>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 371.917)" x="568.126" y="371.917">0</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 335.854)" x="568.126" y="335.854">0.1</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 299.791)" x="568.126" y="299.791">0.2</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 263.728)" x="568.126" y="263.728">0.3</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 227.665)" x="568.126" y="227.665">0.4</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 191.602)" x="568.126" y="191.602">0.5</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 155.539)" x="568.126" y="155.539">0.6</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 119.476)" x="568.126" y="119.476">0.7</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 83.4128)" x="568.126" y="83.4128">0.8</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 47.3498)" x="568.126" y="47.3498">0.9</text>
</g>
<g clip-path="url(#clip00)">
<text style="fill:#000000; fill-opacity:1; font-family:Arial,Helvetica Neue,Helvetica,sans-serif; font-size:12; text-anchor:start;" transform="rotate(0, 568.126, 11.2868)" x="568.126" y="11.2868">1.0</text>
</g>
</svg>




**Input:**

{% highlight julia %}
heatmap(scatter_image(test_images, 4_000))
savefig("mnist_scatter.pdf")
{% endhighlight %}

A high-resolution PDF with more numbers shown can be downloaded from [here]({{site.url}}/images/mnist_scatter.pdf)


So the position of each digit shown on the scatter-plot is given by the level of activation of the coding layer neurons.
Which are basically a compressed repressentation of the image.

We can see not only are the images roughly grouped acording to their number,
they are also positioned accoridng to appeance.
In the top-right it can be seen arrayed are all the ones.
With there posistion (seemingly) determined by the slant.
Other numbers with similarly slanted potions are positioned near them.
The implict repressentation found using the autoencoder unviels hidden properties of the images.

# Conclusion

We have presented a few fairly basic neural network models.
Hopefully, the techneques shown encourage you to experiment further with machine learning with Julia, and TensorFlow.jl.

