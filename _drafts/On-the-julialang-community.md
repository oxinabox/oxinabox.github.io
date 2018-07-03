---
title: On The JuliaLang Community
tags: julia
---


People often talk about Julia being great because
 - it's fast
 - it's multiple dispatch is good for scientific computing (See [Jeff's Thesis](https://github.com/JeffBezanson/phdthesis/blob/master/main.pdf)),
 - because it has great syntax for numerical linear algrebra,
 - because it has some really awesome easy to use, and state of the art libraries
 - because it is trival to call C, Fortan, R, Python, etc etc
 
But I am not here to tell you about that.
Julia to me is great because of the people.



I also have a theory that the technical requirement for a common name-space for functions to be overloaded from,
actually helps solve a social issue.
It's been commented that Lua is just too easy, so everyone makes there own things without working together,
thus harming the community.
In julia to make related packages work together, you really want them to be sharing a namespace.
That is what all the packages like StatsBase.jl,  RecipesBase.jl, MathProgBase.jl, are about.
The fact that you need to come together to create those, Base packages,
and then you endup creating a GitHub organisation to maintain them 
forces people to work together.
At least that is my hope.
Making not working together surcifently bad, so that people do work together,
 
 
 


See also [here for some more](https://ucidatascienceinitiative.github.io/IntroToJulia/Html/JuliaMentalModel)
