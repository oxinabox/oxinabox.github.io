# Some early observations on DexLang

The blog post is a break from my usual fare of JuliaLang to talk about something new: DexLang.
`<sarcasm>`
JuliaLang has gotten boring, it is just so stable now.
If a language isn't releasing breaking changes, what even is the point?
`</sarcasm>`
DexLang on the other hand is bleeding edge.
So new in fact it doesn't even have a version number.
So for reference this post is talking about [commit-SHA: 92a9167](https://github.com/google-research/dex-lang/commit/92a916859befc746fa050e55fb71b733d04d21ea)ish.
Somewhere around the 617th commit.

This post is at least half my running notes as I reason about what things are.
So kind of a tutorial.
Also some thoughts on DexLang, and features.

It is probably important to note I've never really done Haskell;
and while F# was once my favorite language, I've not done serious functional programming in well over 5 years.


### Commands:

Dex has a thing that the [parser source](https://github.com/google-research/dex-lang/blob/master/src/lib/Parser.hs#L77) calls commands.
The [Haskell interactive environment](https://downloads.haskell.org/~ghc/7.4.1/docs/html/users_guide/ghci-commands.html) also has a thing called commands, so I assume these are the same idea.
Right now they also work in scripts, but I suspect that is not a feature.
They don't seem to be first class, but just a way to get the REPL to do a thing.
Seems they can only appear before expressions and then they print something straight out.

Here is a list of all of them right now, from the [source](https://github.com/google-research/dex-lang/blob/92a916859befc746fa050e55fb71b733d04d21ea/src/lib/Syntax.hs#L141-L145):

The majority of them are functionality to dump the levels of parsing, lowering, compilation etc.
Which makes sense these are very useful in general, but especially early in the language's development.
That seems to be the following set, which is pretty nice:
```haskell
("parse", ShowParse)
("deshadowed", ShowDeshadowed),
("normalized", ShowNormalized), 
("imp", ShowImp),
("simp", ShowSimp),
("asm", ShowAsm),
("llvm", ShowLLVM),
```

The others:
Type information:
```haskell
("t", GetType),
("typed", ShowTyped),
 ```

Benchmarking:
```haskell
("time", TimeIt),s
("flops", Flops), 
```

IO and plotting:
```haskell
("p", EvalExpr Printed),
("plot", EvalExpr Scatter),
("plotmat", EvalExpr Heatmap),
```