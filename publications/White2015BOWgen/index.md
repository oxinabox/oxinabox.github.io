---
layout: default
title: Generating Bags of Words from the Sums of their Word Embeddings
subtitle: Supplementary Material
---

This page contains supplementary material, code and data used in (White et. al. 2016, Generating Bags of Words from the Sums of their Word Embeddings)[../White2015BOWgen.pdf].

I'm very happy for anyone with any interest in this (or any of my other work) to (get in touch with me)[{{site.url}}/contact].

Use of this data or code on this page of these should cite the paper:

```
	{% include_relative White2015BOWgen.bib %}
```

##Proof of NP-Hardness of Vector Selection Problem
The vector selection problem is NP-Hard. It is possible to reduce from any given instance of a \emph{subset sum problem} to a vector selection problem. The \emph{subset sum problem} is NP-complete \parencite{karp1972reducibility}. It is defined: for some set of integers ($\mathcal{S}\subset\mathbb{Z}$), does there exist a subset ($\mathcal{L}\subseteq\mathcal{S}$) which sums to zero ($0=\sum_{l_i\in \mathcal{L}} l_i$).  A suitable metric, target vector and  vocabulary of vectors corresponding to the elements $\mathcal{S}$ can be defined by a bijection; such that solving the vector selection problem will give the subset of vectors corresponding to a subset of $\mathcal{S}$ with the smallest sum; which if zero indicates that the subset sum does exists, and if nonzero indicates that no such subset ($\mathcal{L}$) exists. A fully detailed proof of the reduction from subset sum to the vector selection problem can be found by following the link below

 - [Full Proof](complexity_working.pdf)
 
The proof is a little fiddly, and complex, but does not use any higher maths beyond basic linear algebra.


##Core Code Only
For those who which to understand or implement the BOW generation algorithm.
This is written in the (Julia programming language)[http://julialang.org/]. Nominally v0.5.

 - [core code]

##Data and Code
The below is complete package to reproduce the results.
It includes all inputs, all part stage outputs, full code for preprocessing, processing and analysing the results and even the (Julia programming language)[http://julialang.org/].
Note that this includes input data, and various libraries, all of which are under their own licenses (included). Our own contributions are liscensed under the MIT license.
 
 - [Data and Code](full.zip)





