---
title: My other JuliaLang posts and videos of 2019
tags: julia
layout: default
---
If you follow my blog, it may look like I am blogging a fair bit less this last year.
Infact I am blogging just as much, but collaborating more.
So my posts end up hosted elsewhere.
Also since I am no longer the only julia user in 3000km, I am giving more talks.
For this post I thought I would gather things up so I can find them again. 
<!--more-->

This list is arranged roughly most recent first.

### The Emergent Features of JuliaLang
This was original a talk I was invited to give to PyData Meetup Cambridge, and the Julia Users Group London.
Unfortunately, neither time was recorded, but it is now a pair of very nice blog posts (even if I do say so my self).
Main reason for how nice they are is the great editting from 
Cozmin Ududec, Eric Permin Martins, and Eric Davies.

The first is a bit of a grab-bag of random tricks, that you mostly shouldn't do,
but that helps with understanding.
The second is about traits, which are actually really useful.

 - [The Emergent Features of JuliaLang: Part I](https://invenia.github.io/blog/2019/10/30/julialang-features-part-1/)
 - [The Emergent Features of JuliaLang: Part 2 -- Traits](https://invenia.github.io/blog/2019/11/06/julialang-features-part-2/)

### JuliaCon 2019 Reflections
Nick Robinson managed to convince a bunch of peole at Invenia to contribute to a blog post on this years JuliaCon.
This post worked out to be a nice little summary of a subset of the talks.
I was the Vice-Program Chair for this JuliaCon (and also am again for 2020),
so I am biased and think all the talks that we selected were great.
But this post talks about some of them in a little more detail.

 - [JuliaCon 2019](https://invenia.github.io/blog/2019/08/09/juliacon/)

### Building A Debugger with Cassette
This was my JuliaCon talk on [MagneticReadHead](https://github.com/oxinabox/MagneticReadHead.jl) a debugger I wrote.
The talk have a great outcome for me: afterwards Valentin Churavy, gave me some suggestions that resulted in [rewritting the core](https://github.com/oxinabox/MagneticReadHead.jl/issues/73) of it to use some of the compilers tools.
This was a great JuliaCon for me for levelling up my compiler skills.
Nathan Daly and I worked on [StagedFunctions.jl](https://github.com/NHDaly/StagedFunctions.jl/) at the hackaton which significantly relaxes the restrictions `@generated` functions have.
That also set the stage for my `static_hasmethod` which allows for compile time dispatch on whether or not a method exits.
That code currently lives in [Tricks.jl](https://github.com/oxinabox/Tricks.jl/blob/1695b6c42709e134167027154c8e8ebe43b7e86a/src/Tricks.jl), it may not be the best way to do it, but I think it always works (hard to prove).

<iframe width="560" height="315" src="https://www.youtube.com/embed/lTR6IPjDPlo" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
<br>

### DiffEqFlux: Neural Differential Equations
It is an utter privilege to get to collaborate with Chris Rackauckas, Mike Innes, Yingbo Ma, Jesse Bettencourt, and Vaibhav Dixit.
Chris and I have been playing with various mixes of Machine Learning and Differential Equations for a few years.
This is where some of those ideas and a bunch more ended up.
Fun fact: Jesse Bettencourt's supervisor is David Duvenaud, who was one of the original founders of Invenia (my employer).

 - [DiffEqFlux.jl – A Julia Library for Neural Differential Equations](https://julialang.org/blog/2019/01/fluxdiffeq)

### TensorFlow.jl and other tools for ML in JuliaLang
I'm not doing much with TensorFlow.jl these days, its stable, it works.
Though I am now involved in the framework agnostic [TensorBoardLogger.jl](https://github.com/PhilipVinc/TensorBoardLogger.jl/)
which is a great project, I strongly encourage anyone who has some iterative method to consider logging with it.

Anyway, this was a talk about how TensorFlow.jl is used.
TensorFlow.jl remains (In my biased opinion) one of the most comprehensive, and ideomatic wrappers of TensorFlow.
I've moved on to using Flux.jl because it is more ideomatic, and as I found out when preparing this talk,
often faster (Limitted benchmarks, CPU only).
Though, it is much easier to write slow Flux code than  slow TensorFlow.jl code.
The preparation of this talk, and me debugging those performance issues, is the reason why Flux now has a [performance tips section.](https://fluxml.ai/Flux.jl/stable/performance/).

I have lost the video for this one and if anyone finds it, can they let me know?
I know it was recorded, but I can't find where it ended up.
It was given to a combined meetup of the [London Julia Users Group,
and the London Deep Learning Lab](https://www.meetup.com/London-Julia-User-Group/events/257956548/).

 - [Slide and Demo notebooks from TensorFlow and other tools for ML in JuliaLang](https://github.com/oxinabox/oxinabox.github.io/tree/32180120d0be51fe44783ab23ba8b8187b42fd91/_drafts/JuliaDeepLearningMeetupLondon2019)

I also recommend [this video by Jon Malmaud](https://www.youtube.com/watch?v=n2MwJ1guGVQ) at the TensorFlow Dev Summit.
