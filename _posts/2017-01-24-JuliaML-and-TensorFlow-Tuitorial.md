---
layout: default
title: "JuliaML and TensorFlow Tuitorial"
tags:
    - julia
    - jupyter-notebook
---
This is a demonstration of using JuliaML and TensorFlow to train an LSTM network.
It is based on  [Aymeric Damien's LSTM tutorial in Python](https://github.com/aymericdamien/TensorFlow-Examples/blob/master/notebooks/3_NeuralNetworks/recurrent_network.ipynb). 
All the explinations are my own, but the code is generally similar in intent.
There are also some differences in terms of network-shape.

The task is to use LSTM to classify MNIST digits.
That is image recognition.
The normal way to solve such problems is a ConvNet.
This is not a sensible use of LSTM, after all it is not a time series task.
The task is made into a time series task, by the images arriving one row at at a time;
and the network is asked to output which class at the end after seeing the 28th row. 
So the LSTM network must remember the last 27 prior rows.
This is a toy problem to demonstrate that it can.


To do this we are going to use a bunch of packages from the [JuliaML Org](https://github.com/JuliaML), as well as a few others.
A lot of the packages in JuliaML are evolving fast, so somethings here may be wrong.
You can install the packages used in this demo by running:
`Pkg.add.(["TensorFlow", "Distributions", "ProgressMeter", "MLLabelUtils", "MLDataUtils"])`,
and `Pkg.clone("https://github.com/JuliaML/MLDatasets.jl.git")`.
MLDatasets.jl is not yet registers so you need to clone that one.
Also right now (24/01/2017), we are using the **dev** branch of MLDataUtils.jl,
so you will need to do the `git checkout` stuff to make that work,
but hopefully very soon that will be merged into master, so just the normal `Pkg.add` will surfice.
You also need to install [TensorFlow](https://www.tensorflow.org/get_started/os_setup), as it is not automatically installed by the TensorFlow.jl package.
We will go through each package we use in turn. <!--more-->

**In [1]:**

{% highlight julia %}
using TensorFlow
using Distributions
using ProgressMeter
using MLLabelUtils
using MLDataUtils
using MLDatasets
using Base.Test
{% endhighlight %}

We will begin by defining some of the parameters for our network as constants.
Out network has 28 inputs -- one row of pixels, and each image consists of 28 time steps so each row is shown.
The other parameters whould be fairly self explainitory.

**In [2]:**

{% highlight julia %}
#Training Hyper Parameter
const learning_rate = 0.001
const training_iters = 2 #Just two, becuase I don't have anything to stop overfitting and I don't got all day
const batch_size = 256
const display_step = 100 #How often to display the 

# Network Parameters
const n_input = 28 # MNIST data input (img shape: 28*28)
const n_steps = 28 # timesteps
const n_hidden = 128 # hidden layer num of features
const n_classes = 10; # MNIST total classes (0-9 digits)
{% endhighlight %}

{% highlight plaintext %}

{% endhighlight %}

We are going to use the MNIST distribution, from the [MLDatasets.jl](https://github.com/JuliaML/MLDatasets.jl/).
It is a handy way to get hold of the data.
The first time you call one of its data functions it will download the data.
After that it will load it from disk.
It is a nice implementation, simply done using `file(path) || download(url, path)` at the start of the method.
I would like to implement something similar for [CorpusLoaders.jl](https://github.com/oxinabox/CorpusLoaders.jl)
We check its shape -- the data is a 3D Array, `(col,row,item)`, and the labels are integers.
We also define a quick imshow function to draw ascii art so we cha check it out.

**In [3]:**

{% highlight julia %}
const traindata_raw,trainlabels_raw = MNIST.traindata();
@show size(traindata_raw)
@show size(trainlabels_raw)

imshow(x) = join(mapslices(join, (x->x ? 'X': ' ').(x'.>0), 2), "\n") |> print
@show trainlabels_raw[8]
imshow(traindata_raw[:,:,8])

{% endhighlight %}

{% highlight plaintext %}
size(traindata_raw) = (28,28,60000)
size(trainlabels_raw) = (60000,)
trainlabels_raw[8] = 3
                            
                            
                            
                            
                            
           XXXXXXXXXXX      
         XXXXXXXXXXXXXX     
         XXXXXXXXXXXXXX     
         XXXXXXXXXXXXXX     
         XXXX    XXXXXX     
                 XXXXX      
                XXXXXX      
              XXXXXXXX      
         XXXXXXXXXXXX       
        XXXXXXXXXXX         
        XXXXXXXXXXXX        
         XXXXXXXXXXX        
                XXXX        
                XXXX        
      XXX      XXXXX        
     XXXX    XXXXXXX        
     XXXXXXXXXXXXXX         
     XXXXXXXXXXXXX          
     XXXXXXXXXXX            
      XXXXXXX               
                            
                            
                            
{% endhighlight %}

We use  [MLLabelUtils.jl](https://github.com/JuliaML/MLLabelUtils.jl/) to encode the labels and [MLDataUtils.jl](https://github.com/JuliaML/MLDataUtils.jl) to segment the labels and the data into minibatchs. That is how those two packages fit together.
If it applies to only labelled data, eg Encodings then it is done with MLLabelUtils.
If it applies to data in general, eg partitioning the data, the it is done with MLDataUtils.
They are nice stand-alone packages that can be chained in with other JuliaML packages,
or used in a independant system. Which is more like what we are doing here with TensorFlow.jl.


When it comes to encoding the labels, we use `convertlabel` from MLLabelUtils.
Its signiture is `convertlabel(output_encoding, input_labels, input_encoding)`.
We provide both the desired (output) encoding, and the current (input) encoding.
This ensure that the input is interpretted correctly and constantly.
If we do not provide the input encoding, then MLDataUtils would infer the encoding.
The encoding it would infer (because the input is not strictly positive integers) is that the labels are arbitary.
It would thus devise a `NativeLabel` Mapping, based on the order the labels occur in input.
That mapping would not be saved anywhere, so when it comes time to encode the test data, we don't know which index corresponds to which label symbol. 
So we declare the input_label. (Alternatives would be to infor it using `labelenc(labels_raw)` and then record the inferred encoding for later. Or to add 1 to all the raw labels so it is in the range 1:10, which causes the labels to be inferred as `LabelEnc.Indices{Int64,10}()`)

To break the data down into minibatchs, we use a `BatchView` from MLDataUtils.
BatchView is an iterator and efficiently returns it back 1 minibatch at a time.
There are a few requirement on the input iterator,
but a julia Array meets all of them.
It also nicely lets you specify which dimention the observations are on,
but in ourcase it is the last, which is the default.
We will use the data in batchs later, once we have defined the network graph.

**In [4]:**

{% highlight julia %}
"""Makes 1 hot encoded labels."""
encode(labels_raw) = convertlabel(LabelEnc.OneOfK, labels_raw, LabelEnc.NativeLabels(collect(0:9)))


const trainlabels = BatchView(encode(trainlabels_raw), batch_size)
const traindata = BatchView(traindata_raw, batch_size);

@testset "data_prep" begin
    @test encode([4,1,2,3,0]) ==   [ 0  0  0  0  1
                                     0  1  0  0  0
                                     0  0  1  0  0
                                     0  0  0  1  0
                                     1  0  0  0  0
                                     0  0  0  0  0
                                     0  0  0  0  0
                                     0  0  0  0  0
                                     0  0  0  0  0
                                     0  0  0  0  0 ]
    @test size(first(traindata)) ==  (n_steps, n_input, batch_size)
    @test size(first(trainlabels)) ==  (n_classes, batch_size)
end;
{% endhighlight %}

{% highlight plaintext %}
<span class="ansi-blue-intense-fg ansi-bold">INFO: The specified values for size and/or count will result in 96 unused data points
</span><span class="ansi-blue-intense-fg ansi-bold">INFO: The specified values for size and/or count will result in 96 unused data points
</span>
{% endhighlight %}

{% highlight plaintext %}
<span class="ansi-white-intense-fg ansi-bold">Test Summary: | </span><span class="ansi-green-intense-fg ansi-bold">Pass  </span><span class="ansi-blue-intense-fg ansi-bold">Total</span>
  data_prep   | <span class="ansi-green-intense-fg ansi-bold">   3  </span><span class="ansi-blue-intense-fg ansi-bold">    3</span>

{% endhighlight %}

Now to define the network graph, this is done using [TensorFlow.jl](https://github.com/malmaud/TensorFlow.jl).
[TensorFlow](https://www.tensorflow.org/) is basically a linear algebra tool-kit, featuring automatic differentiation, and optimisation methods.
Which makes it awesome for implementing neural networks.
It does have some neural net specific stuff (A lot of which is in `contrib` rather than core `src`) such as the LSTMCell,
but it is a lot more general than just neural networks.
It's more like Theano, than it is like Mocha, Caffe or SKLearn.
This means is actually flexible enough to be useful for (some) machine learning research, rather than only for apply standard networks.
Which is great, because I get tired of doing the backpropergation calculus by hand on weird network topologies.
But today we are just going to use it on a standard kind of network, this LSTM. 

We begin by defining out variables in a fairly standard way.
This is very similar to what you would see in a feedward net, see the [examples from Tensorflow.jl's manual](https://malmaud.github.io/tfdocs/logistic/).
For our purposes, TensorFlow has 4 kinda of network elements:

 - **Placeholders**, like `X` and `Y_obs` -- these are basically input elements. We declare that this symbol is a Placeholder for data we are going to feed in when we `run` the network
 - **Variables**, like `W`, `B`, and what is hidden inside the `LSTMCell` -- these are things that can be adjusted during training
 - **Derived Values**, like `Y_pred`, `cost`, `accuracy`, `Hs` and `x` -- these nodes hold the values returned from some operation, they can by your output, or they can be steps in the middle of a chain of such operations.
 - **Action Nodes**, like `optimizer`. When these nodes are interacted with (eg Output from `run`), they do *something* to the network. `optimizer` in our adjusts the *Variables* to optimise the value of its function input -- `cost`.
 
The last two terms, **Derived Values** and **Action Nodes**, I made up.
It has how I think of them, but your probably won't see it in any kind of offical documentation, or in the source code.


So we first declare our inputs as Placeholders.
You will note that they are being sized into Batchs here.
We then define the varaiables `W` and `B`; 
note that [we use `get_variable` that than declaring it directly](http://stackoverflow.com/q/37098546/179081),
because in general that is the preferred way, and it lets us use the initializer etc.
We use the Normal distribution as an initialiser. This comes from [Distributions.jl](https://github.com/JuliaStats/Distributions.jl).
It is set higher variance than I would normally use, but it seems to work well enough.


**In [6]:**

{% highlight julia %}
sess = Session(Graph())
X = placeholder(Float32, shape=[n_steps, n_input, batch_size])
Y_obs = placeholder(Float32, shape=[batch_size, n_classes])

variable_scope("model", initializer=Normal(0, 0.5)) do
    global W = get_variable("weights", [n_hidden, n_classes], Float32)
    global B = get_variable("bias", [n_classes], Float32)
end;
{% endhighlight %}

We now want to hook the input `X` into an RNN, made using `LSTMCell`s.
To do this we need the data to be a list of tensors (matrixs since 2),
where

- each element of the list is a different time step, (i.e. a different row of the each image)
- going down the second index of the matrix moves within a single input step (i.e. along the same row of the orginal image)
- and going down the first index puts you on to the next item in the batch.

Initially we have `(steps, observations, items)`, we are going to use `x` repeatedly as a temporary variable.
We use `transpose` to reorder the indexes, so that it is  `(steps, items, observations)`.
Then `reshape` to merge/splice/weave the first two indexes into once index `(steps-items, observations)`.
Then `spit` to cut along every the first index making a list of tensors `[(items1,observations1), (items2,observations2), ...]`.
This feels a bit hacky as a way to do it, but it works.
I note here that `transpose` feels a little unidiomatic in particuar, since it ise 0-indexed, and need the cast to Int32 (you'll get an errror without that), and since the matching julia function is called `permutedims` -- I would not be surprised if this changed in future versions of TensorFlow.jl.

**In [7]:**

{% highlight julia %}
# Prepare data shape to match `rnn` function requirements
# Current data input shape: (n_steps, n_input, batch_size) from the way we declared X (and the way the data actually comes)
# Required shape: 'n_steps' tensors list of shape (batch_size, n_input)
    
x = transpose(X, Int32.([1, 3, 2].-1)) # Permuting batch_size and n_steps. (the -1 is to use 0 based indexing)
x = reshape(x, [n_steps*batch_size, n_input]) # Reshaping to (n_steps*batch_size, n_input)
x = split(1, n_steps, x) # Split to get a list of 'n_steps' tensors of shape (batch_size, n_input)
@show get_shape.(x);
{% endhighlight %}

{% highlight plaintext %}
get_shape.(x) = TensorFlow.ShapeInference.TensorShape[TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28],TensorShape[256, 28]]

{% endhighlight %}

Now we connect it `LSTMcell` and we put that cell into an `rnn`.
The `LSTMcell` makes up all the LSTM machinery, with forget gates etc,
and the `rnn` basically multiplies them and hooks it up to their `x`.
It returns the output hidden layers `Hs` and the `states`. 
We don't really care about the `states`
but `Hs` is a list of **Derived Value** kind of tensors.
There is one of them for each of the input steps.
We want to hook up only the last one to our next softmax stage, so we do so with `Hs[end]`.

Finally we hook up the output layer to get `Y_pred`.
Using a fairly standard softmax formulation.
[Aymeric Damien's Python code](https://github.com/aymericdamien/TensorFlow-Examples/blob/master/notebooks/3_NeuralNetworks/recurrent_network.ipynb) doesn't seem to use a softmax output.
I tried without a softmax output and I couldn't get it to work at all.
Y
This may be to do with the `rnn` and `LSTMCell` in julia being a little crippled.
They don't have the full implementation of the Python API.
In particular I couldn't workout a way to initialise the `forget_bias` to one,
so I am not sure if it is not messing it up and becoming a bit unstable at times.
Also, right now there is only support for static `rnn`  rather than the `dynamic_rnn` which all the cool kids apparently use(See *rnn vs. dynamic_rnn*  in [this article](http://www.wildml.com/2016/08/rnns-in-tensorflow-a-practical-guide-and-undocumented-features/)).
This will probably come in time.

So if all things are correctly setup the shape of the output: `Y_pred` should match the shape of the input `Y_obs`.

**In [8]:**

{% highlight julia %}
Hs, states = nn.rnn(nn.rnn_cell.LSTMCell(n_hidden), x; dtype=Float32);
Y_pred = nn.softmax(Hs[end]*W + B)

@show get_shape(Y_obs)
@show get_shape(Y_pred);
{% endhighlight %}

{% highlight plaintext %}
get_shape(Y_obs) = TensorShape[256, 10]
get_shape(Y_pred) = TensorShape[256, 10]

{% endhighlight %}

Finally we define the last few nodes of out network.
These are the `cost`, for purposes of using to define  the `optimizer`; and the `accuracy`.
The cost is defined using the definition of cross-entropy.
Right now we have to put it in manually, because TensorFlow.jl has not yet implemented that in as `nn.nce_loss` (there is just a stub there).
So we use this cross-entropy as the  cost function for a `AdamOptimizer`, to make out `optimizer` node.

We also make a `accuracy` node for use during reporting.
This is done by counting the portion of the outputs `Y_pred`  that match the inputs `Y_obs`.
Using the cast-the-boolean-to-a-float-then-take-it's-mean trick.

Here, it is worth metioning that nodes in tensorflow that are not between the supplied input and the requested output are not evaluated.
This means that if one does `run(sess, [optimizer], Dict(X=>xs, Y_obs=>ys))` then the `accuracy` node will never be evaluated.
It does not need to be evaluated to get the `optimizer` node (but `cost`, does).
We will run the network in the next step


**In [9]:**

{% highlight julia %}
cost = reduce_mean(-reduce_sum(Y_obs.*log(Y_pred), reduction_indices=[1])) #cross entropy
@show get_shape(Y_obs.*log(Y_pred))
@show get_shape(cost) #Should be [] as it should be a scalar

optimizer = train.minimize(train.AdamOptimizer(learning_rate), cost)

correct_prediction = indmax(Y_obs, 2) .== indmax(Y_pred, 2)
@show get_shape(correct_prediction)
accuracy = reduce_mean(cast(correct_prediction, Float32));

{% endhighlight %}

{% highlight plaintext %}
get_shape(Y_obs .* log(Y_pred)) = TensorShape[256, 10]
get_shape(cost) = TensorShape[]
get_shape(correct_prediction) = TensorShape[unknown]

{% endhighlight %}

Finally we can run our training.
So we go through a zip of traindata and trainlabels we prepared earlier,
run the optimizer on each.
and periodically check the accuracy of that last batch to give status updates.
It is all very nice.

**In [10]:**

{% highlight julia %}
run(sess, initialize_all_variables())

kk=0
for jj in 1:training_iters
    for (xs_a, ys_a) in zip(traindata, trainlabels)
        xs = collect(xs_a)
        ys = collect(ys_a)'
        run(sess, optimizer,  Dict(X=>xs, Y_obs=>ys))
        kk+=1
        if kk % display_step == 1
            train_accuracy, train_cost = run(sess, [accuracy, cost], Dict(X=>xs, Y_obs=>ys))
            info("step $(kk*batch_size), loss = $(train_cost),  accuracy $(train_accuracy)")
        end
    end
end
{% endhighlight %}

{% highlight plaintext %}
<span class="ansi-blue-intense-fg ansi-bold">INFO: step 256, loss = 62.762604,  accuracy 0.1171875
</span><span class="ansi-blue-intense-fg ansi-bold">INFO: step 25856, loss = 29.060556,  accuracy 0.671875
</span><span class="ansi-blue-intense-fg ansi-bold">INFO: step 51456, loss = 15.045149,  accuracy 0.76953125
</span><span class="ansi-blue-intense-fg ansi-bold">INFO: step 77056, loss = 13.506208,  accuracy 0.859375
</span><span class="ansi-blue-intense-fg ansi-bold">INFO: step 102656, loss = 10.518069,  accuracy 0.8671875
</span>
{% endhighlight %}

Finally we check how we are going on the test data.
However, as all our nodes have been defined in terms of batch_size,
we are going to need to process the test data in minibatches  also.
I feel like these should be a cleaner way to do this that that.

This is a chance to show of the awesomeness that is [ProgressMeter.jl](https://github.com/timholy/ProgressMeter.jl) `@show_progess`.
This displace a unicode-art progress bar, marking progress through the iteration.
Very neat.

**In [11]:**

{% highlight julia %}
testdata_raw, testabels_raw = MNIST.testdata()
testlabels = BatchView(encode(testabels_raw), batch_size)
testdata = BatchView(testdata_raw, batch_size);


batch_accuracies = []
@showprogress for (ii, (xs_a, ys_a)) in enumerate(zip(testdata, testlabels))
    xs = collect(xs_a)
    ys = collect(ys_a)'

    batch_accuracy = run(sess, accuracy, Dict(X=>xs, Y_obs=>ys))
    #info("step $(ii),   accuracy $(batch_accuracy )")
    push!(batch_accuracies, batch_accuracy)
end
@show mean(batch_accuracies) #Mean of means of consistantly sized batchs is the overall mean
{% endhighlight %}

{% highlight plaintext %}
<span class="ansi-blue-intense-fg ansi-bold">INFO: The specified values for size and/or count will result in 16 unused data points
</span><span class="ansi-blue-intense-fg ansi-bold">INFO: The specified values for size and/or count will result in 16 unused data points
</span>
{% endhighlight %}

{% highlight plaintext %}
Progress: 100%|█████████████████████████████████████████| Time: 0:00:06
mean(batch_accuracies) = 0.90334535f0

{% endhighlight %}

{% highlight plaintext %}

{% endhighlight %}

90\% accuracy, not bad for an unoptimised network -- particularly one as unsuited to the tast as LSTM.
I hope this introduction the JuliaML and TensorFlow has been enlightening.
There is lots of information about TensorFlow online, though to unstand the julia wrapper I had to look at the source-code more ofthen than the its docs. But that will get better with maturity, and the docs line up the the Python API quiet well a lot of the time.
The docs for the new version of MLDataUtils are still being finished off (that is the main blocker on it being merged as I understand it).
Hopefully tuitorials like this lets you see how these all fit together to do something useful.
