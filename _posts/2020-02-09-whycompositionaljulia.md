---
layout: default
title: "JuliaLang: The Ingredients for a Composable Programming Language"
tags:
    - julia
    - jupyter-notebook
---

One of the most remarkable things about the julia programming language,
is how well the packages compose.
You can almost always reuse someone else's types or methods in your own software without issues.
This is generally taken on a high level to be true of all programming languages because that is what a library is.
However, experienced software engineers often note that its surprisingly difficult in practice to take something from one project and use it in another without tweaking.
But in the julia ecosystem this seems to mostly work.
This post explores some theories on why;
and some loose recommendations to future language designers.
<!--more-->


This blog post is based on a talk I was invited to give at the 2020 [F(by) conference](http://fby.dev).
This blog post is a bit ad-hoc in its ordering and content because of its origin as a talk.
I trust the reader will forgive me.

<iframe width="560" height="315" src="https://www.youtube.com/embed/W6MagCe2XZI" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>


Parts of this post (and the talk) are inspired by [Stefan Karpinski's "The Unreasonable Effectiveness of Multiple Dispatch" talk at JuliaCon 2019](https://www.youtube.com/watch?v=kc9HwsxE1OY).
I recommend that video, it goes into more details on some of the multiple dispatch points, and the subtle (but important) difference between julia's  dispatch and C++'s virtual methods.


## What do I mean by composable?

### Examples:

 - If you want to add tracking of measurement error to a scalar number, you shouldn't have to say anything about how your new type interacts with arrays **([Measurements.jl](https://github.com/JuliaPhysics/Measurements.jl))**
 - If you have a Differential Equation solver, and a Neural Network library, then you should just be able to have neural ODEs (**[DifferentialEquations.jl](https://github.com/JuliaDiffEq/DifferentialEquations.jl) / [Flux.jl](https://github.com/FluxML/Flux.jl)**)
 - If you have a package to add names to the dimensions of an array, and one to put arays on the GPU, then you shouldn't have to write code to have named arrays on the GPU (**[NamedDims.jl](https://github.com/invenia/NamedDims.jl) / [CUArrays.jl](https://github.com/JuliaGPU/CuArrays.jl)**)

### Why is julia this way?

My theory is that julia code is so reusable,
not just because the language has some great features, but also because of the particular features that are **weak or missing.**

Missing features like:
 - Weak conventions about namespace pollution
 - Never got around to making it easy to use local modules, outside of packages
 - A type system that can't be used to check correctness

But that these are countered by, or allow for other features:
 - Strong convention about talking to other people
 - Very easy to create packages
 - Duck-typing, and multiple dispatch, together


## Julia namespacing is used in a leaky way

Common advice when loading code from another module in most language communities is:
only import what you need.
e.g `using Foo: a, b c`

Common practice in julia is to do:
`using Foo`,
which imports everything that the author of `Foo` marked to be **exported**.

You don't have to, but it's common.

But what happens if one has a pair of packages:
 - `Foo` exporting `predict(::FooModel, data)`
 - and `Bar` exporting `predict(::BarModel, data)`,

and one does:
```julia
using Foo
using Bar
training_data, test_data = ...
mbar = BarModel(training_data)
mfoo = FooModel(training_data)
evaluate(predict(mbar), test_data)
evaluate(predict(mfoo), test_data)
```

If you have multiple `using`s trying to bring the same name into scope,
then julia throws an error, since it can't work out which to use.

As a user you can tell it what to use.

```julia
evaluate(Bar.predict(mbar), test_data)
evaluate(Foo.predict(mfoo), test_data)
```

### But the package authors can solve this:
There is no name collision if both names overloaded are from the *same namespace*.

If both `Foo` and `Bar` are overloading `StatsBase.predict` everything works.

```julia
using StatsBase  # exports predict
using Foo  # overloads `StatsBase.predict(::FooModel)
using Bar  # overloads `StatsBase.predict(::BarModel)
training_data, test_data = ...
mbar = BarModel(training_data)
mfoo = FooModel(training_data)
evaluate(predict(mbar), test_data)
evaluate(predict(mfoo), test_data)
```


### This encourages people to work together

Name collisions make package authors come together and create base packages (like `StatsBase`) and agree on what the functions mean.

They don't have to, since the user can still solve it, but it encourages the practice.
Thus we have package authors thinking about how other packages might be used with theirs.

Package authors can even overload functions from multiple namespaces if you want;
e.g. all of `MLJBase.predict`, `StatsBase.predict`, `SkLearn.predict`.
Which might all have slightly different interfaces targetting different use cases.


## Its easier to create a package than a local module.

Many languages have one module per file,
and you can load that module e.g. via
`import Filename`
from your current directory.

You can make this work in julia also, but it is surprisingly fiddly.

What is easy however, is to create and use a package.

### What does making a local module generally give you?

 - Namespacing
 - The feeling you are doing good software engineering
 - Easier to transition later to a package

### What does making a julia package give you?
 - All the above plus
 - Standard directory structure, `src`, `test` etc
 - Managed dependencies, both what they are, and what versions
 - Easy re-distributivity -- harder to have local state
 - Test-able using package manager's `pkg> test MyPackage`

The [recommended way](https://github.com/invenia/PkgTemplates.jl/) to create packages also ensures:

 - Continuous Integration(/s) Setup
 - Code coverage
 - Documentation setup
 - License set

### Testing julia code is important.
Julia uses a JIT compiler, so  even compilation errors don't arrive until run-time.
As a dynamic language the type system says very little about correctness.

Testing julia code is important.
If code-paths are not covered in tests there is almost nothing in the language itself to protect them from having any kind of error.

So it's important to have Continuous Integration and other such tooling set up.

### Trivial package creation is important

Many people who create julia packages are not traditional software developers; e.g. a large portion are academic researchers.
People who don't think of themselves as "Developers" are less inclined to take the step to turn their code into a package.


Recall that many julia package authors are graduate students who are trying to get their next paper complete.
Lots of scientific code never gets released, and lots of the code that does never gets made usable for others.
But if they start out writing a package (rather than a local module that just works for their script) then it is already several steps closes to being released.
Once it is a package people start thinking more like package authors, and start to consider how it will be used.

It's not a silver bullet but it is one more push in the right direction.

## Multiple Dispatch + Duck-typing

**Assume it walks like a duck and talks like a duck, and if it doesn't fix that.**

Julia's combination of duck-typing with multiple dispatch is quite neat.
It lets us have support for any object that meets the implict interface expected by a function ([duck-typing](https://en.wikipedia.org/wiki/Duck_typing));
while also having a chance to handle it as a special-case if it doesn't (multiple dispatch).
In a fully extensible way.

This pairs to the weakness of julia in its lack of a static type system.
A static type system's benefits comes from ensuring interfaces are met at compile time.
This largely makes in-compatible with duck-typing.
(There are other interesting options in this space though, e.g. [Structural Typing](https://en.wikipedia.org/wiki/Structural_type_system).)



The example in this section will serve to illustrate how duck-typing and multiple dispatch give the expressivity that is escential for composability.

---

#### Aside: Open Classes
Another closely related factor is **Open Classes.**
But I'm not going to talk about that today, I recommend finding other resources on it.
Such as [Eli Bendersky's blog post on the expression problem](https://eli.thegreenplace.net/2016/the-expression-problem-and-its-solutions#is-multiple-dispatch-necessary-to-cleanly-solve-the-expression-problem).
You need to allow new methods to be added to existing classes.
Some languages (e.g. Java) require that methods literally be placed inside the same file as the class.
This means there is no way to add methods in another code-base, even unrelated ones.

---

### We would like to use some code from a library
Consider I might have a type from the **Ducks** library.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
struct Duck end

walk(self) = println("🚶 Waddle")
talk(self) = println("🦆 Quack")

raise_young(self, child) = println("🐤 ➡️ 💧 Lead to water")
{% endhighlight %}
</div>

and I have some code I want to run, that I wrote:

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
function simulate_farm(adult_animals, baby_animals)
    for animal in adult_animals
        walk(animal)
        talk(animal)
    end

    # choose the first adult and make it the parent for all the baby_animals
    parent = first(adult_animals)
    for child in baby_animals
        raise_young(parent, child)
    end
end
{% endhighlight %}
</div>

#### Lets give it a try:

3 Adult ducks, 2 Baby ducks:
**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
simulate_farm([Duck(), Duck(), Duck()], [Duck(), Duck()])
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
🚶 Waddle
🦆 Quack
🚶 Waddle
🦆 Quack
🚶 Waddle
🦆 Quack
🐤 ➡️ 💧 Lead to water
🐤 ➡️ 💧 Lead to water
{% endhighlight %}
</div>

Great, it works

#### Ok now I want to extend it with my own type. A Swan

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
struct Swan end
{% endhighlight %}
</div>

Lets test with just 1 first:
<div class="jupyter-input jupyter-cell">
{% highlight julia %}
simulate_farm([Swan()], [])
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
🚶 Waddle
🦆 Quack
{% endhighlight %}
</div>

The **Waddle** was right, but Swans don't **Quack**.

We did some duck-typing -- Swans walk like ducks,
but they don't talk like ducks.


We can solve that with **single dispatch**.

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
talk(self::Swan) = println("🦢 Hiss")
{% endhighlight %}
</div>


**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
simulate_farm([Swan()], [])
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
🚶 Waddle
🦢 Hiss
{% endhighlight %}
</div>


Great, now lets try a whole farm of Swans:

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
simulate_farm([Swan(), Swan(), Swan()], [Swan(), Swan()])
{% endhighlight %}
</div>

**Output:**
<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
🚶 Waddle
🦢 Hiss
🚶 Waddle
🦢 Hiss
🚶 Waddle
🦢 Hiss
🐤 ➡️ 💧 Lead to water
🐤 ➡️ 💧 Lead to water
{% endhighlight %}
</div>

That's not right. Swans do not lead their young to water.

They carry them

![](https://p1.pxfuel.com/preview/695/84/40/nature-bird-swan-young-royalty-free-thumbnail.jpg)

Once again we can solve this with **single dispatch**.

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
raise_young(self::Swan, child::Swan) = println("🐤 ↗️ 🦢 Carry on back")
{% endhighlight %}
</div>


Trying again:

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
simulate_farm([Swan(), Swan(), Swan()], [Swan(), Swan()])
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
🚶 Waddle
🦢 Hiss
🚶 Waddle
🦢 Hiss
🚶 Waddle
🦢 Hiss
🐤 ↗️ 🦢 Carry on back
🐤 ↗️ 🦢 Carry on back
{% endhighlight %}
</div>

#### Now I want a Farm with mixed poultry.

2 Ducks, a Swan, and 2 baby swans

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
simulate_farm([Duck(), Duck(), Swan()], [Swan(), Swan()])
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
🚶 Waddle
🦆 Quack
🚶 Waddle
🦆 Quack
🚶 Waddle
🦢 Hiss
🐤 ➡️ 💧 Lead to water
🐤 ➡️ 💧 Lead to water
{% endhighlight %}
</div>


Thats not right again.

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
🐤 ➡️ 💧 Lead to water
{% endhighlight %}
</div>

What happened?

We had a Duck raising a baby Swan, and it lead the baby Swan to water.

If you know about raising poultry, then you will know:
_Ducks given baby Swans to raise, will just abandon them._



But how will we code this?

### Option 1: Rewrite the Duck

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
function raise_young(self::Duck, child::Any)
    if child isa Swan
        println("🐤😢 Abandon")
    else
        println("🐤 ➡️ 💧 Lead to water")
    end
end
{% endhighlight %}
</div>

#### Rewriting the Duck has problems
 - Have to edit someone else's library, to add support for *my* type.
 - This could mean adding a lot of code for them to maintain.
 - Does not scale, what if other people wanted to add Chickens, Geese etc.

##### Variant: Monkey-patch
 - If the language supports [monkey patching](https://en.wikipedia.org/wiki/Monkey_patch), could do it that way.
 - but it means copying their code into my library, will run into issues like not being able to update.
 - Scaled to other people adding new types even worse, since no longer a central canonical source to copy.

##### Variant: could fork their code
 - That is giving up on code reuse.

##### Design Patterns
There *are* engineering solutions around this.
Design patterns allow one to emulate features a language doesn't have.
For example the `Duck` could allow for one to `register` behaviour with a given baby animal,
which is basically adhoc runtime multiple dispatch.
But this would require the `Duck` to be rewritten this way.

### Option 2: Inherit from the Duck

(NB: this example is **not** valid julia code)
<div class="jupyter-input jupyter-cell">
{% highlight julia %}
struct DuckWithSwanSupport <: Duck end

function raise_young(self::DuckWithSwanSupport, child::Any)
    if child isa Swan
        println("🐤😢 Abandon")
    else
        raise_young(upcast(Duck, self), child)
    end
end
{% endhighlight %}
</div>

#### Inheriting from the Duck has problems:
 - Have to replace every `Duck` in my code-base with `DuckWithSwanSupport`
 - If I am using other libraries that might return a `Duck` I have to deal with that also
 - Again there are design patterns that can help, like using [Dependency Injection](https://en.wikipedia.org/wiki/Dependency_injection) to control how all `Ducks` are created. But now all libraries have to be rewritten to use it.

##### Still does not scale:
If someone else implements `DuckWithChickenSupport`, and I want to use both their code and mine, what do I do?

 - Inherit from both? `DuckWithChickenAndSwanSupport`
 - This is the classic multiple inheritance [Diamond Problem](https://en.wikipedia.org/wiki/Multiple_inheritance#The_diamond_problem).
 - It's hard. Even in languages supporting multiple inheritance, they may not support it in a useful way for this without me writing special cases for many things.


### Option 3: Multiple Dispatch

This is clean and easy:

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
raise_young(parent::Duck, child::Swan) = println("🐤😢 Abandon")
{% endhighlight %}
</div>

Trying it out:

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
simulate_farm([Duck(), Duck(), Swan()], [Swan(), Swan()])
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
🚶 Waddle
🦆 Quack
🚶 Waddle
🦆 Quack
🚶 Waddle
🦢 Hiss
🐤😢 Abandon
🐤😢 Abandon
{% endhighlight %}
</div>


## Are there real-world use cases for Multiple Dispatch ?

Turns out there are.

The need to extend operations to act on new combinations of types shows up all the time in scientific computing.
I suspect it shows up more generally, but we've learned to ignore it.


If you look at a [list of BLAS methods](http://www.netlib.org/blas/#_level_3) you will see just this encoded in the function name
E.g.
 - `SGEMM` - matrix matrix multiply
 - `SSYMM` - symmetric-matrix matrix multiply
 - ...
 - `ZHBMV` - complex hermitian-banded-matrix vector multiply

And turns out people keep wanting to make more and more matrix types.

 - Block Matrix
 - Banded Matrix
 - Block Banded Matrix (where the band is made up of blocks)
 - Banded Block Banded Matrix (where the band is made up of blocks that are themselved banded).

That is before other things you might like to do to a Matrix, which you'd like to encode in its type:
 - Running on a GPU
 - Tracking Operations for AutoDiff
 - Naming dimensions, for easy lookup
 - Distributing over a cluster

These are all important and show up in crucial applications.
When you start applying things across disciplines, they show up even more.
Like advancements in Neural Differential Equations, which needs:

 - all the types machine learning research has invented,
 - and all the types differential equation solving research has invented,

and wants to use them together.

So its not a reasonable thing for a numerical language to say that they've enumerated all the matrix types you might ever need.

## Inserting a human into the JIT

### Basic functionality of an Tracing JIT:

 - Detect important cases via tracing
 - Compile specialized methods for them

This is called specialization.

### Basic functionality of julia's JIT:

 - Specialize all methods on all types that they are called on as they are called

This is pretty good: it is a reasonable assumption that the types are going to an important case.

### What does multiple dispatch add on top of julia's JIT?

It lets a human tell it how that specialization should be done.
Which can add a lot of information.

### Consider Matrix multiplication.

We have

- `*(::Dense, ::Dense)`:
    - multiply rows by columns and sum.
    - Takes $O(n^3)$ time


 - `*(::Dense, ::Diagonal)` or `*(::Diagonal, ::Dense)`:
    - column-wise/row-wise scaling.
    - $O(n^2)$ time.


 - `*(::OneHot, ::Dense)` or `*(::Dense, ::OneHot)`:
    - column-wise/row-wise slicing.
    - $O(n)$ time.


 - `*(::Identity, ::Dense)` or `*(::Dense, ::Identity)`:
    - no change.
    - $O(1)$ time.


### Anyone can have basic fast array processing by throwing the problem to BLAS, or a GPU.

But not everyone has Array types that are parametric on their scalar types;
and the ability to be equally fast in both.

Without this, your array code, and your scalar code can not be disentangled.

BLAS for example does not have this.
It has a unique code for each combination of scalar and matrix type.

With this separation, one can add new scalar types:
 - Dual numbers
 - Measurement Error tracking numbers
 - Symbolic Algebra numbers

Without ever having to touch array code, except as a late-stage optimization.

Otherwise, one needs to implement array support into one's scalars, to have reasonable performance at all.

## It is good to invent new languages

People need to invent new languages.
It's a good time to be inventing new languages.
It's good for the world.
It's good for me because I like cool new things.

I’d just really like those new languages to please have:
 - Multiple dispatch, to:
     - allow for extension via whatever special case is needed in _separate packages_. (E.g. The Duck will lead a baby duck to water, but will abandon a baby swan)
     - Include allowing domain knowledge to be added (Like the matrix multiplication examples)
 - Open classes:
     - so you can create new methods in your package for types/functions declared in another package
 - Array types that are parametric on their scalar types, at the type level
     -  So that array-code and scalar-code do not need to be entangled for performance.
 - A package management solution built-in, that everyone uses.
     - because it makes for consistent tooling and a multiplicative effect on software standard.
     - Like everyone in the julia community writing tests and using CI.
 - Not jumping straight onto 1 namespace per file, isolate everything, bandwagon.
     - Namespace clashes are not that bad
     - Its worth considering what the value of namespaces is: not just _"Namespaces are one honking great idea -- let's do more of those!"_


---

Thanks to Cormullion,  Jens Adam, Casey Kneale, and Mathieu Besançon for proof reading.
