# A NonHaskell programmers introduction to early DexLang

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

It is important to note I've never really done Haskell.
I've done a few tutorials years ago, but never really used it.
I did a fair bit o F# at uni and liked it a lot used it for a few projects then, but again that was years ago.
So I am no real functional programmer, let that be clear.


### Commands:

Dex has a thing that the [parser source](https://github.com/google-research/dex-lang/blob/master/src/lib/Parser.hs#L77) calls commands.
The [Haskell interactive environment](https://downloads.haskell.org/~ghc/7.4.1/docs/html/users_guide/ghci-commands.html) also has a thing called commands, so I assume these are the same idea.
Right now they also work in scripts, but I suspect that is not a feature.
They don't seem to be first class, but just a way to get the REPL to do a thing.
Seems they can only appear before expressions and then they print something straight out.

A list of all of them right now, can be found in the [source](https://github.com/google-research/dex-lang/blob/92a916859befc746fa050e55fb71b733d04d21ea/src/lib/Syntax.hs#L141-L145).
I quite like the Dex source code.

The main ones are introduced in the tutorial:
Type information:
```haskell
("t", GetType),
("p", EvalExpr Printed),
 ```

`:p` is eval and print.
So it is `show` in julia.
I am not sure what `:p` does, that just exectuting a line in the REPL doesn't:
```haskell
>=> 1.0 + 1.0
2.0
>=> :p 1.0 + 1.0
2.0
```

`:t` tells you the type of the result, so `typeof` in julia.
```
>=> :t 1.0 + 1.0
Real
```


There are also some for benchmarking:
```haskell
("time", TimeIt),
("flops", Flops), 
```


And some for plotting, which I will not discuss further as I can only get Dex to run on a headless VM right now.
```haskell
("plot", EvalExpr Scatter),
("plotmat", EvalExpr Heatmap),
```


But the majority of them are functionality to dump the levels of parsing, lowering, compilation etc.
Which makes sense these are very useful in general, but especially early in the language's development.
That seems to be the following set, which is pretty nice:
```haskell
("parse", ShowParse),
("typed", ShowTyped),
("deshadowed", ShowDeshadowed),
("normalized", ShowNormalized), 
("imp", ShowImp),
("simp", ShowSimp),
("asm", ShowAsm),
("llvm", ShowLLVM),
```

