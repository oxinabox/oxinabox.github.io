---
title: JuliaPro beta 0.5.02 first impressions
layout: default
tags:
   - julia
---

[JuliaPro](http://juliacomputing.com/products/juliapro.html) is JuliaComputing's prepackaged bundle of julia, with Juno/Atom IDE, and a bunch of packages. The short of it is: there is no reason not to install julia this way on a Mac/Windows desktop -- it is more convenient and faster to setup, but it is nothing revolutionary.
<!--more-->
JuliaComputing is the company formed by several of the julia core devs to provide paid support contracts etc, while earning money to let them continue developing the language. Paid support contracts are things that industry users want from a product -- this also funds many linux distros.

JuliaPro thus comes with a [free version, and a Enterpise version](https://shop.juliacomputing.com/Products/?page_id=7435) -- at $1499 annually. Beyond the support contract, the only features the free version is missing is the Excel Integration.
To me Dataframes have replaced Excel a long time ago. But Excel is incredibly heavily used in industry -- even more so than in research science. This is a bad thing.

Apparently, GPL-free version, and [Intel MKL](https://software.intel.com/en-us/intel-mkl) (BLAS) are coming soon to JuliaPro Enterpise. These are things that are fairly easy to setup when building julia from source. Intel MKL is actually available free -- which is news to me. So I have downloaded the non-paid version, on to a windows computer that has never had julia before.

Installing seemed clean, easy and quick. Faster than building from source that is for sure. Installed looked basic, but functional. Nothing insane in the user agreement. To install for all users, I had to close and restart the installer, rather than being prompted to escalate privilege. Which is marginally annoying, but not a big deal. Took less than 5 minutes to install.

I went to start Juno. Typed Juno into that start bar.
Up came "Juno for JuliaPro". When it started, it ran a process to initialize -- which took about as long as the installer in the first place. It was hands free, and once it started Juno was working fine.
I restarting it, and it seemed like the completion wasn't working, but it kicked in after a minute or so, so all is good.

Tested console, it works, and code 'completion works.
Juno seems to be all working ok (Its also a lot better than when I last looked at it when it first came out).
I tested plotting: with Gadfly -- which is included in JuliaPro, whereas [Plots.jl](https://github.com/JuliaPlots/Plots.jl) is not.

It also includes [JuMP](http://jump.readthedocs.io/).
However, no solvers as include. Which is kind of useless, since JuMP needs at least one solver.
I went to do `Pkg.add("GLPKMathProgInterface")`, and the console appeared to hang for serveral minutes. I restarted a few times. After installing the solver i could now run a JuMP example.  I think this delay in installing is a known julia and windows issue, so I guess it will be fixed in the JuliaPro onces it is fixed in julia. This is one of those broken features that make julia look pretty unshiny on Windows.

There is nothing surpising in the packages include,
it all seems very sensible. Most of the packages are fairly small, and mature as far as anything in julia is.

My conclusions are that this is a very easy way to install julia on windows. I like this a lot better then install julia, then Atom, then Juno, and then going through the configuration process. This is nice, it saves a fair bit of time and messing around. It could be more polished, but it is nice enough, nothing incredibly broken. I would never *not* install julia on Windows (or Mac) using JuliaPro, this is just better than installing it piece by piece.. There is no linux build, or I would used that on my linux desktop also.

---

#### Update (4/5/2017)
I see it now has Linux support as well.
I am yet to test.

