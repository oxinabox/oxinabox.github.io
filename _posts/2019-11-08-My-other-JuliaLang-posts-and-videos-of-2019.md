---
title: My other JuliaLang posts and videos of 2019
tags: julia
layout: default
---
If you follow my blog, it may look like I am blogging a fair bit less this last year.
The reason for this is actually that I have been blogging about as much,
but as part of collaborations, and so it is hosted elsewhere.
In this post I gather up all the posts I have collaborated on in the last year,
and also some videos of talks I have given.
<!--more-->

This list is arranged most recent first.

## The Emergent Features of JuliaLang
This was original a talk I was invited to give to PyData Meetup Cambridge, and the Julia Users Group London.
Unfortunately, neither time was recorded, it is now a pair of very nice blog posts (even if I do say so my self).
Main reason for how nice they are is the great editting from 
Cozmin Ududec, Eric Permin Martins, and Eric Davies.

The first is a bit of a grab-bag of random tricks, that you mostly shouldn't do,
but that helps with understanding.
The second is about traits, which are actually really useful.

 - [The Emergent Features of JuliaLang: Part I](https://invenia.github.io/blog/2019/10/30/julialang-features-part-1/)
 - [The Emergent Features of JuliaLang: Part 2 -- Traits](https://invenia.github.io/blog/2019/11/06/julialang-features-part-2/)

## JuliaCon 2019 Reflections
Nick Robinson managed to convince a bunch of peole at Invenia to contribute to a blog post on this years JuliaCon.
This post worked out to be a nice little summary of a subset of the talks.
I was the Vice-Program Chair for this JuliaCon (and also am again for 2020),
so I am biased and think all the talks that we selected were great.
But this post talks about some of them in a little more detail.

 - [JuliaCon 2019](https://invenia.github.io/blog/2019/08/09/juliacon/)

## Building A Debugger with Cassette
This was my JuliaCon talk on [MagneticReadHead](https://github.com/oxinabox/MagneticReadHead.jl) a debugger I wrote.
The talk have a great outcome for me: afterwards Valentin Churavy, gave me some suggestions that resulted in [rewritting the core](https://github.com/oxinabox/MagneticReadHead.jl/issues/73) of it to use some of the compilers tools.
This was a great JuliaCon for me for levelling up my compiler skills.
Nathan Daly and I worked on [StagedFunctions.jl](https://github.com/NHDaly/StagedFunctions.jl/) at the hackaton which significantly relaxes the restrictions `@generated` functions have.
That also set the stage for my `static_hasmethod` which allows for compile time dispatch on whether or not a method exits.
That code currently lives in [Tricks.jl](https://github.com/oxinabox/Tricks.jl/blob/1695b6c42709e134167027154c8e8ebe43b7e86a/src/Tricks.jl), it may not be the best way to do it, but I think it always works (hard to prove).

<iframe width="560" height="315" src="https://www.youtube.com/embed/lTR6IPjDPlo" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

## DiffEqFlux: Neural Differential Equations
It is an utter privilege to get to collaborate with Chris Rackauckas, Mike Innes, Yingbo Ma, Jesse Bettencourt, and Vaibhav Dixit.
Chris and I have been playing with various mixes of Machine Learning and Differential Equations for a few years.
This is where some of those ideas and a bunch more ended up.
Fun fact: Jesse Bettencourt's supervisor is David Duvenaud, who was one of the original founders of Invenia (my employer).

 - [DiffEqFlux.jl – A Julia Library for Neural Differential Equations](https://julialang.org/blog/2019/01/fluxdiffeq)


