---
title: Is Julia Good for AI?
layout: default
tags:
   - julia
---


It seems like one of the most common questions asked of Julia: "Is Julia good for AI?".
I'm not sure why it is asked so often.
Cynically, I think it is asked by people who are both new to the language and new to the field.
The question can't be readily answered without first defining AI.


AI is notoriously hard to define:
I'll quote Wikipedia's article on the AI Effect:

>The AI effect occurs when onlookers discount the behavior of an artificial intelligence program by arguing that it is not real intelligence.
>Author Pamela McCorduck writes: "It's part of the history of the field of artificial intelligence that every time somebody figured out how to make a computer do something—play good checkers, solve simple but relatively informal problems—there was chorus of critics to say, 'that's not thinking'." AI researcher Rodney Brooks complains "Every time we figure out a piece of it, it stops being magical; we say, 'Oh, that's just a computation.'"

However, that is a question of the lay-persons definition of AI.
Even the definitions of people in the field make AI a broad area.

ACM defines both AI and Machine Learning (ML) as subfields of [Computational Methodology](http://dl.acm.org/ccs/ccs.cfm?id=10010147). Most, but not all, things people call AI are from within Computational Methodology.
For example, many would consider biologically inspired systems like Evolutionary Algorithms, and Swarm algorithms to also be related to AI (They are under Mathematics of computing →  Mathematical analysis →  Mathematical optimization).
As well consider, Information Retieval to related also -- particularly since it in many ways includes the tech behind Digital Assistants like Siri etc (Information systems →  Information retrieval).
Most often today, people casually saying AI actually mean Machine Learning; in particular Deep Learning with Neural Networks.


I think it is useful to distinguish between AI and ML.
They are not the same thing; but are related.
AI is giving the appearance of intelligence -- doing things that we normally think only a person could do.
Machine learning is to have the computer in some sense learn to solve a problem from data, rather than having an explicit algorithm for solving that problem written by the programmer.
In general ML is used in the implementation of AI; but it is not AI itself.

Some would say that learning is something we we would normally think only a person could do.
Thus it could be argued that ML is infact AI.
This is getting down into semantics; ML is definitely in the broader class of AI, but not normally in the narrower case of doing things we normally think humans are the only ones who can do.
Most of the recent deep learning excitement is over offline, supervised methods.
These are not very human at all.
As compared to Active Learning, Oneshot Learning, Reinforncement learning and several other ML techniques which can be argued to be more "human".
In general though I will discuss ML as distinct for the classical focus of AI.

No taxonomy or set of definitions is perfect.
Remember Diogenes' plucked checken: "Behold, a man."
For informative purposes though, I am going to go though various fields and talk about how good (or otherwise) julia is for them.


## Planning and Searching
Being able to make plans sounds like an real AI thing at first.
Then one realises that is is reducable to searching through a space of possible plans.
Thus the problem is reduced to algorithmic searching. 


### Game Playing and Classical Planning
This is the core of classic AI. There is no magic here. The knowledge is all from how the designer represents the problem.

This area tends to be covered by ACM as:
 - [Artificial intelligence →  Search methodologies](http://dl.acm.org/ccs/ccs.cfm?id=10010205&lid=0.10010178.10010205&CFID=975588983&CFTOKEN=56546358) 
    - Especially [→  Game tree search](http://dl.acm.org/ccs/ccs.cfm?id=10010210&lid=0.10010178.10010205.10010210&CFID=975588983&CFTOKEN=56546358)
	- and [→  Discrete space search](http://dl.acm.org/ccs/ccs.cfm?id=10010207&lid=0.10010178.10010205.10010207&CFID=975588983&CFTOKEN=56546358)
 - [Artificial intelligence →  Planning and scheduling](http://dl.acm.org/ccs/ccs.cfm?id=10010199&lid=0.10010178.10010199&CFID=975588983&CFTOKEN=56546358)
    - Especially [→  Planning for deterministic actions](http://dl.acm.org/ccs/ccs.cfm?id=10010200&lid=0.10010178.10010199.10010200&CFID=975588983&CFTOKEN=56546358)

Many articles are dual coded under both.
State Graph searches are the key way by which classical (deterministic) planning problems are solved.
Many game playing problems reduce to be very similar to deterministic planning problems, if one assumes a rational opponent.


	
#### Domain Description

This is automated [Game Theory](https://en.wikipedia.org/wiki/Game_theory) -- assuming one counts one-player, or environment as a player games.
One takes a real world problem, and converts it into a graph, then searches that graph for the optimal outcome.
In a general way, this tends to involve building a [graph](https://en.wikipedia.org/wiki/Graph_(discrete_mathematics)) such that:

 - **Vertexes** (nodes) represent **states**
   - In chess: the position of every piece
   - In navigation: the location of the car. Probably represented as an intersection.
 - **Edges** (connections between nodes) represent actions one can take to change the states**
   - In chess: ♞g1-f3 moving a knight,
   - In navigation: take the 3rd next right
   - Which edges exist depends on the current state. If there is no knight at ♞g1 then ♞g1-f3 is not an edge that can be considered.
   - In some problems the edges have weights -- in navigation that is the distance driven between this interection and the next.   
 - **Terminal Vertexes** represent end states
   - The game is over, one has reached the destination.

The goal is to define a **path** through the graph to the terminal vertex, while optimising some criteria.
A path through the graph is a sequence of actions to reach ones goal.
The criteria could be a condition on the terminal node: In chess one wishes to reach a node where one wins,
or on the path -- in navigation one wants to minimise to total distance travelled.

The algorithms also often feature heuristics, which allow one to to estimate the score of a partially complete path.
For chess this is often some measure on how many pieces are left.
For navigation this is often the distance as the crow flies from the final location in the partial path to the goal, plus the distance travelled so far on the path.
These heuristics are useful because often finding the true score requires searching an exponential number of paths to reach the terminal nodes.
The heuristics can be used to prioritise, or sometimes eliminate undesirable paths. 

#### Algorithms
Well known algorithms from this field of AI include:
 - [A\*] e.g for navigation](https://en.wikipedia.org/wiki/A*_search_algorithm)
 - [Minimax with Alpha-beta pruning](https://en.wikipedia.org/wiki/Alpha%E2%80%93beta_pruning)
 - [Breadth-first search](https://en.wikipedia.org/wiki/Breadth-first_search) and [Depth-first search](https://en.wikipedia.org/wiki/Depth-first_search)
 - [Best-first search](https://en.wikipedia.org/wiki/Best-first_search) and [Beam search](https://en.wikipedia.org/wiki/Beam_search)
 
#### Is Julia good for this?

This is some very classic CS algorithms stuff.
Almost every procedural programming language is good for this.

Having fast loops, does make julia marginally more suited to this than many languages (like R, Octave, and older versions of Matlab) which prefer vectorised routines.
This code is loop heavy.
Having excellent mathematical syntax helps a little with some more complicated heuristic functions.

One nice thing I've found when working with graph-like structures is the ability to use multiple-dispatch to process different kinds of vertexes or edges differently.
That does apply here.
If one has a function `update_state(::AbstractMove, ::AbstractState)`, one can define various overloads for differnet kinds of moves,
and different kinds of state.
For example a move in chess could be a `Reposition{Knight}("g1", "f3")` or `Castle(::Kingside)`.
However, one does not normally need to dispatch both on multiple types of Move and multiple types of State (dispatching on state all is rare),
in the stame system.
And single-dispatch in a normal object orientated language can handle that just fine.


To conclude, julia is not particularly good at Artificial intelligence →  Search methodologies.
There is certainly nothing wrong with it, but I don't see any strong motivation to switch to Julia to do search methodology work.

  
### Non-deterministic Planning (Markov decision processes)
These are in many ways generalisations of Classical Planning discussed above.

This area tends to be covered by ACM as:
 - [Artificial intelligence →  Planning and scheduling](http://dl.acm.org/ccs/ccs.cfm?id=10010199&lid=0.10010178.10010199&CFID=975588983&CFTOKEN=56546358)
    - Especially [→  Planning under uncertainty](http://dl.acm.org/ccs/ccs.cfm?id=10010201&lid=0.10010178.10010199.10010201&CFID=975588983&CFTOKEN=56546358)
 - [Artificial intelligence →  Search methodologies](http://dl.acm.org/ccs/ccs.cfm?id=10010205&lid=0.10010178.10010205&CFID=975588983&CFTOKEN=56546358) 
    - Especially [→   Search with partial observations](http://dl.acm.org/ccs/ccs.cfm?id=10010212&lid=0.10010178.10010205.10010212&CFID=975588983&CFTOKEN=56546358)

This is well outside of my own area so my coverage will be brief.

#### Domain Description

The problems solves here are similar to the ones defined before for  Game Playing and Classical Planning.
They are still (normally) described as a graph of states, with actions transitioning between them.
The added complication in the case of Non-deterministic planning problem is that some of the features are variable.
In the Markov decision process it is which state an action leads to is not deterministically known.
Rather reach action has associated with it a set of possible transitions each with a probability.
This can represent for example a variety of board-games like where one picks from a number of possible moves then rolls a dice to determine the outcome.
It can also be used for reasoning about a number of more realistic scenarios.

Another area is [partially observable planning problems](https://en.wikipedia.org/wiki/Partially_observable_Markov_decision_process),
where the current state (vertex) can not be fully known.


#### Algorithms
Well known algorithms from this field of AI include:
 - Methods to optimise the [Bellman equation](https://en.wikipedia.org/wiki/Bellman_equation)
    - [Value Iteration](https://www.cs.cmu.edu/afs/cs/project/jair/pub/volume4/kaelbling96a-html/node19.html) 
    - [Policy Iteration](https://www.cs.cmu.edu/afs/cs/project/jair/pub/volume4/kaelbling96a-html/node20.html)
 - Many less well known algorithms for various variants, eg [Hamilton–Jacobi–Bellman partial differential equation](https://en.wikipedia.org/wiki/Hamilton%E2%80%93Jacobi%E2%80%93Bellman_equation)

 
#### Is Julia good for this?

Yes, julia is good for this.
Julia is much better for this than most traditional programming languages.
The key feature of these problems as compared to those discussed earlier  is the increase in mathematical complexity.
In non-scientific/technical languages, doing even relatively simple math can become a pain of external libraries, poor syntax and variable performance.
By relatively simple, I mean things solving a set of simulations equations -- as is often done as part of Policy Iteration.
Languages like Mathematica, Matlab, Octave, R and Julia make these kind of operation simple.
Julia is good for this, but not massively more than any other technical language.

When it gets into more advanced variants, julia's package ecosystem comes to shine.
The more advanced variants require more advanced mathematics.
Julia has a very solid set of package being created.
We can contrast this to Matlabs mine-field of unmaintained scripts, plus and expensive official toolkits,
In particular of interest here is [Distributions.jl](https://juliastats.github.io/Distributions.jl/latest/) for defining systems,
[JuMP](http://www.juliaopt.org/JuMP.jl/latest/) which is an utterly excellent toolkit for constrained optimisation,
and [DifferentialEquations.jl](https://github.com/JuliaDiffEq/DifferentialEquations.jl) which is likely the most comprehensive and optimised differential equation solver in the world.
When it comes to the parts of AI that brush up against advanced mathematics (i.e the advanced forms of Non-deterministic Planning),
julia probably is a solid step forward.


## Human Tasks
There as some tasks which have been considered "Human" for want of a better description.
They are considered AI, because being able to solve them is considered the domain of what intelligent creatures do.

### Natural Language Processing & Information Retrieval

Some might argue that Information Retrival and NLP are separate fields.
ACM certainly does
 - [Artificial intelligence →  Natural language processing](http://dl.acm.org/ccs/ccs.cfm?id=10010179&lid=0.10010178.10010179&CFID=975588983&CFTOKEN=56546358)
 - [Information systems →  Information retrieval](http://dl.acm.org/ccs/ccs.cfm?id=10003317&lid=0.10002951.10003317&CFID=975588983&CFTOKEN=56546358)

Historically, [Natural Language Processing](https://en.wikipedia.org/wiki/Information_retrieval#History) was focused on machine translation,
and [Information Retrieval](https://en.wikipedia.org/wiki/Information_retrieval#History) was focused on indexing.
However, these have significantly converged.
Correct machine translation, requires natural language understanding for there is not a simple unambiguous mapping between human languages.
Correct information retrieval also requires natural language understanding, because similarly, the same idea may be expressed in different ways by the same language -- and the idea is the true thing one must index from.

A large portion of the remainder of NLP almost exists as steps towards achieving natural language understanding.
Since Information Retrieval also needs this it has (relatively recently) converged.
However, the overlap now is huge.


#### Domain

What I call the core NLP stack of tasks is (roughly in order, though some steps can be skipped or others done in parallel):
- Tokenization/Lexing
  - Breaking a sentence up into tokens
  - Tokens are normally words, but also sentences, and paragraphs.
  - On the other end multi-word expressions like "American Airlines", or "bad hair day" should often be considered as single token. (Though sometimes this can wait for the parsing step)
  - Basically trivial in English, but more difficult in other languages.
- Part of Speech (POS) Tagging 
  - This is determining if something is a noun, verb etc. often with consideration to tenses as well.
  - This is a sequence-sequence problem, assign 1 output for every input tokens
- Parsing
  - Structure the text into some form of tree of clauses.
  - A relatively fiddly, graph building problem.
- Word Sense Disambiguation (WSD)
  - Words have multiple meanings, according to a lexical resource like a dictionary.
  - WSD is to determine which sense is being used
  - A very difficult problem. Most systems struggle to overcome the baseline "Always use most common word sense for this POS"  
- Named Entity Recognition
  - Detecting entities and assigning them to classes: normally Person, Organisation and Location
  - Basically WSD for proper nouns.
  - Important for Information Retrieval as things we want to know about tend to be named entitites. 
- Co-reference resolution
  - Resolving references to the same entity as being such
  - Detecting that "The boy was the one who he mistook for his own reflection", referred to 2 entities: "the boy"="the one", and "he"="his"
  
If one goes down the entire stack, one ends up with a rich semantically graph of information,
though little of it is much higher than word level.
One often aborts the stack much earlier, e.g. after tokenization.

Then one has higher level task such as:

- Topic Detection
- Image Captioning/Image Retrieval
- Intent Detection
- Sentiment Analysis
- Natural Language Generation
- Machine Translation

#### Algorithms

#### Is julia good for this



### Computer Vision

#### Algorithms

#### Is julia good for this


















