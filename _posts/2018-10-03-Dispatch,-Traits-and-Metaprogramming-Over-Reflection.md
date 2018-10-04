---
layout: default
title: "Dispatch, Traits and Metaprogramming Over Reflection"
tags:
    - julia
    - jupyter-notebook
---
This is a blog post about about dispatch.
Mostly, single dispatch, though it trivially generalises to multiple dispatch,
because julia is a multiple dispatch language.

This post starts simple, and becomes complex.

 - Beginning with, introductory julia skills: _dispatch_
 - continue to intermidate julia skills: _traits_
 - and finishing up with advanced techniques: _metaprogramming over reflection_
 
The last of which is kinda evil.

<!--more-->


I think dispatch is very intutitive as a concept.
In C you learn that a function's signature,
is composed of it's name, and the types of the arguments and the return type.
So it would make sense that you could define a different function, depending on the types.
(but you can't).


In a dynamic language you are supposed  not worrying **too much** about the type of your values.
I feel that the emphisis should be on on not worrying too much: you need to worry **just the right amount**.
[Duck-typing](https://en.wikipedia.org/wiki/Duck_typing) is great.
But reasoning about types is very easy.
It is the kind of reasoning we do all the time.

Dispatch is about striking the balance between exploiting knowledge of a type,
and being general.
I can write general code that doesn't worry about the types,
and then add extra methods based on the types of the arguments for special cases.

## Part 1: Displaying a Percentage

I would like to display a value as a percentage.
So that is pretty easy, if I have some portion, (e.g `0.5`),
I can convert it to a percentage by multipling it by `100` (e.g. `100 × 0.5 = 50`),
then I print it and append a `%` sign.


**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
display_percent(x) = println(100x,"%") 
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
display_percent (generic function with 1 method)
{% endhighlight %}


</div>

That gives me a general rule that works for most types.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
display_percent(0.5) #Float64
display_percent(0.5f0) #Float32
display_percent(BigFloat(π)/10) #BigFloat
display_percent(1) #Int64
display_percent(false) #Bool
display_percent(2//3) #Rational
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
50.0%
50.0%
3.141592653589793238462643383279502884197169399375105820974944592307816406286212e+01%
100%
0%
200//3%

{% endhighlight %}
</div>

I'm not exactly happy with how that `Rational` displayed,
it is correct, but I would rather it was displayed not as a fraction.
So we can fix it by adding a new method for `Rational`s.

Our current method has no type constraints.
We will create one that has a constraint that the argument must be a `Rational`.
More specific methods, i.e. ones with tighter type constraints are called over ones with looser constraints.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
display_percent(x::Rational) = println(round(100x; digits=2), "%")
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
display_percent (generic function with 2 methods)
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
display_percent(2//3) #Rational
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
66.67%

{% endhighlight %}
</div>

That worked great.

What if I am given a String as input,
that is already a percentage?

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
display_percent("5.81%")
{% endhighlight %}
</div>

**Output:**


    MethodError: no method matching *(::Int64, ::String)
    Closest candidates are:
      *(::Any, ::Any, !Matched::Any, !Matched::Any...) at operators.jl:502
      *(!Matched::Missing, ::AbstractString) at missing.jl:139
      *(::T<:Union{Int128, Int16, Int32, Int64, Int8, UInt128, UInt16, UInt32, UInt64, UInt8}, !Matched::T<:Union{Int128, Int16, Int32, Int64, Int8, UInt128, UInt16, UInt32, UInt64, UInt8}) where T<:Union{Int128, Int16, Int32, Int64, Int8, UInt128, UInt16, UInt32, UInt64, UInt8} at int.jl:54
      ...

    

    Stacktrace:

     [1] display_percent(::String) at ./In[1]:1

     [2] top-level scope at In[5]:1


We get an error, because there is no method to do 100 times a `String`;
and multiplying the string by 100 isn't what we want to do anyway.
So we can define a special method for how to display a string as a percent.
It is going to check the string is in the correct format,
and if so display it.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
function display_percent(str::AbstractString)
    if occursin(r"^\d*\.?\d+%$", str)  # any combination of numbers, followed by a percent sign
        println(str)
    else
        throw(DomainError(str, "Not valid percentage format"))
    end
end
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
display_percent (generic function with 3 methods)
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
display_percent("5.81%")
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
5.81%

{% endhighlight %}
</div>

Great, fixed it.

Where this really comes in handy is working with things you as the programmer don't know the type of, when you are writing the code.
For example if you have a hetrogenous list of elements to process.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
for x in [0.51, 0.6, 1//2, 0.1, "2%"]
    display_percent(x)
end
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
51.0%
60.0%
50.0%
10.0%
2%

{% endhighlight %}
</div>

Real world example of this sort of code is in [solving for indexing rules in TensorFlow.jl](https://github.com/malmaud/TensorFlow.jl/blob/d7ac7e306ca95122c2583c9db06f9e7405102275/src/ops/indexing.jl#L69-L98).

So dispatch is useful, it lets you write different rules for how to handle different types.
Dispatch goes very nicely in a dynamically typed language.
Since (type-unstable) functions can return different types, depending on inputs,
and some types (like our `String` and our `Rational`) might want to be handled differently,
we need a good way of dealing with those cases.

        
It is also nicely extensible.
Lets say we created a singleton type to represent a half.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
struct Half
end

display_percent(::Half) = println("50%")
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
display_percent (generic function with 4 methods)
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
display_percent(Half())
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
50%

{% endhighlight %}
</div>

So it was simple to just add a new method for it.

Users can add support for new types,
completely separate from the original definition.

Constrast it to:

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
function display_percent_bad(x)
     if x isa AbstractString
        if occursin(r"^\d*\.?\d+%$", x)  # any combination of numbers, followed by a percent sign
            println(x)
        else
            throw(DomainError(x, "Not valid percentage format"))
        end
    else
        println(100x, "%")
    end
end
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
display_percent_bad (generic function with 1 method)
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
display_percent_bad("5.3%")
display_percent_bad(0.5)
display_percent_bad(Half())
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
5.3%
50.0%

{% endhighlight %}
</div>


    MethodError: no method matching *(::Int64, ::Half)
    Closest candidates are:
      *(::Any, ::Any, !Matched::Any, !Matched::Any...) at operators.jl:502
      *(::T<:Union{Int128, Int16, Int32, Int64, Int8, UInt128, UInt16, UInt32, UInt64, UInt8}, !Matched::T<:Union{Int128, Int16, Int32, Int64, Int8, UInt128, UInt16, UInt32, UInt64, UInt8}) where T<:Union{Int128, Int16, Int32, Int64, Int8, UInt128, UInt16, UInt32, UInt64, UInt8} at int.jl:54
      *(::Union{Int16, Int32, Int64, Int8}, !Matched::BigInt) at gmp.jl:463
      ...

    

    Stacktrace:

     [1] display_percent_bad(::Half) at ./In[11]:9

     [2] top-level scope at In[12]:3


You can see, that since it doesn't include support for `Half` when it was declared,
it doesn't work,
and you can't do much to make it work.

This kinda code is common in a fair bit of python code.


## Part 2: `AsList`, (including using traits)

The kind of code which uses `if` conditionals,
is quite common in practice.

In [Python TensorFlow has a helper function](https://github.com/tensorflow/tensorflow/blob/r1.11/tensorflow/python/ops/gradients_impl.py#L202-L203), `_AsList`:

```python
def _AsList(x):
    return x if isinstance(x, (list, tuple)) else [x]
```

It's purpose is to convert scalar values,
into lists with one item.
So it checks if the input is a `list` or a `tuple`,
and if it is, then it makes no change,
if not then it wraps it in a `list`.

Problem with this is,
what if my input is a type it didn't expect.
But which actually 
[duck-types](https://en.wikipedia.org/wiki/Duck_typing) as a `list`, as fair as the functionality required is concerned.
e.g. perhaps a [`dequeue`](https://docs.python.org/3/library/collections.html#collections.deque).
Then the code will break.
My `dequeue` will be mangled into a `list` containing a `deque`,
which won't index or iterate correctly.
And there is nothing I can do about it, except make a PR to TensorFlow.
(or perhaps as a hack, [monkey-patch](https://en.wikipedia.org/wiki/Monkey_patch) it).

### Example 2.1 direct
The basic  way would be to write methods for each.
Like before.


**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
aslist_direct(x) = [x]
aslist_direct(x::Union{AbstractArray,Tuple}) = x
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
aslist_direct (generic function with 2 methods)
{% endhighlight %}


</div>

The `Union` is just a way of saying the argument needs ot match either of these types.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
@show aslist_direct([1,2,3])
@show aslist_direct(1);
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
aslist_direct([1, 2, 3]) = [1, 2, 3]
aslist_direct(1) = [1]

{% endhighlight %}
</div>

What we are saying is that scalar values do one thing,
and nonscalar values do another.
We can add more rules to `aslist_direct`.
Though we can't add more types to the `Union` so we would have to declare them separately,
which would involve repreated code.

e.g.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
aslist_direct(x::String) = x
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
aslist_direct (generic function with 3 methods)
{% endhighlight %}


</div>

Repeating code is bad.
Further what if we want the notion of _Scalarness_ elsewhere in our code?

One way to handle this and avoid repeating code, would be to use abstract types.
If all our scalar things were a subtype of `AbstractScalar`,
and all out nonscalar things were not,
then we could just write:

```julia
aslist(x::AbstractScalar) = [x]
aslist(x) = x
```

But the types we are concerned with already have super-types (and you can only have one, not multiple inheritance here),
and are already declared.
Abstract supertypes are bit of a gun with only one bullet;
and that bullet needs to be fired when they are declared.

Instread we can use Traits.
There are packages for traits in julia,
but you don't really need them.
We are just going to use Holy Traits (named for Tim Holy, who came up with the idea).


### Example 2.2 Traits

A trait in julia is basically just a pure function of a type, which returns a typed value that is used for dispatch.
They are used to implement a bunch of rules for handling things related to indexing, broadcasting, iterators etc.

Traits are uesful because they let you make declarative statements about a type.
Declarative code is easy to write and read.

Also, note that they are fast.
Since they are pure functions of their input type,
and Julia compiles (and optimises) specialised versions of every function for each combination of input types,
they are compiled away to just being direct static dispatches to the targeted methods.
The trait functions themselves are not actually evaluated at runtime.


Explaining this is going to take a little bit,
but I think traits are an important concept as you move from basic use of julia to something more advanced.
They are are really expressive.
So I think they are worth understanding.

#### Types are values and so have a type
Before we start it is important to understand, is that types are first class in julia.
They are values and they thus have a type.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
@show typeof(String)
@show typeof(Int)
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
typeof(String) = DataType
typeof(Int) = DataType

{% endhighlight %}
</div>

<div class="jupyter-cell">


{% highlight plaintext %}
DataType
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
String isa DataType
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
true
{% endhighlight %}


</div>

So the type of a type (such as `String`) is `DataType`.
A special thing for types though,
is they also act as if they are instances of the special type called `Type`.
This is a parametric type,
and it basically has a rule that `T <: Type{T}`.
Every type  `T` is considered as if it were a subtype of `Type` with the parameter `T`.

It can be used for value-type dispatch.
(Which I will not be going into here, much more,
but see my [StackOverflow post on it](https://stackoverflow.com/q/51568006/179081))

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
@show String isa Type{String}
@show String isa Type{<:AbstractString}
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
String isa Type{String} = true
String isa Type{<:AbstractString} = true

{% endhighlight %}
</div>

<div class="jupyter-cell">


{% highlight plaintext %}
true
{% endhighlight %}


</div>

Mostly, we will want to use triangular dispatch rules.
That is the form `Type{<:AbstractString}`,
also written `Type{T} where T<:AbstractString`,
which allows use to place type constraints on the type parameters.

#### Trait Types

To actually create the trait
we will need to define types for the trait.
This is what the trait function will return.
These should be concrete types.
They don't need any fields -- and indeed generally trait types shouldn't have any fields if possible (it is better to give them type parameters.)
Though they could have super-types,
and is often good to give them a super-type to make them similar.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
abstract type Scalarness end
struct Scalar <: Scalarness end
struct NonScalar <: Scalarness end
{% endhighlight %}
</div>

#### Trait Functions
We are now going to create the trait functions.
These should functions only of the type,
not of the value, so that they can be optimised away at compile time.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
scalarness(::Type) = Scalar() #fall-back, by default everything is scalar
scalarness(::Type{<:AbstractArray}) = NonScalar()
scalarness(::Type{<:Tuple}) = NonScalar()
scalarness(::Type{<:AbstractString}) = NonScalar()
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
scalarness (generic function with 4 methods)
{% endhighlight %}


</div>

Nice, declarative code.
Users can add the scalarness type to their types
similarly.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
@show scalarness(typeof([1,2,3]))
@show scalarness(typeof(1));
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
scalarness(typeof([1, 2, 3])) = NonScalar()
scalarness(typeof(1)) = Scalar()

{% endhighlight %}
</div>

Notice below that it is fully inferable and type-stable.
This will result it being optimised away at compile time during specialisation.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
@code_warntype scalarness(typeof([1,2,3]))
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
Body::NonScalar
│2 1 ─     return $(QuoteNode(NonScalar()))

{% endhighlight %}
</div>

This is what makes it fast.

#### Dispatching on Traits

The whole reason we defined these is so we can use them for dispatch.
We will thus create three functions.
 - One for `aslist` of scalar types,
 - one for `aslist` of nonscalar types,
 - and one to re-dispatch on the trait value.
 
We will begin with the last since it is the first that will be called.



**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
aslist(x::T) where T = aslist(scalarness(T), x)

aslist(::Scalar, x) = [x]
aslist(::NonScalar, x) = x
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
aslist (generic function with 3 methods)
{% endhighlight %}


</div>

Notice how the first is evaluating the trait function(on the type).
The return type of this is used for the dispatch to one of the other two.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
@show aslist([1,2,3])
@show aslist(1);

@show aslist(Set([1,2]));
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
aslist([1, 2, 3]) = [1, 2, 3]
aslist(1) = [1]
aslist(Set([1, 2])) = Set{Int64}[Set([2, 1])]

{% endhighlight %}
</div>

Notice that the `Set` was treated as a scalar, and wrapped in to an array.
Adding a new type is easy.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
scalarness(::Type{<:AbstractSet}) = NonScalar()
@show aslist(Set([1,2]));
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
aslist(Set([1, 2])) = Set([2, 1])

{% endhighlight %}
</div>

## Part 3: Traits, falling back to `hasmethod`

A more advanced stratergy is would be to fall back to `hasmethod`



**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
using LinearAlgebra # Load up LinearAlgebra for more types that might be interesting to know scalarness on
{% endhighlight %}
</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
using InteractiveUtils: hasmethod
scalarness(::Type{T}) where T = hasmethod(Base.iterate, (T,)) ? NonScalar() : Scalar()
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
scalarness (generic function with 5 methods)
{% endhighlight %}


</div>

Now this makes may thing things work without having to define the scalarness trait,
though you would be surprised how many things have `iterate` defined.


**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
@show scalarness(Dict)
@show scalarness(Int);

@show aslist(1)
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
scalarness(Dict) = NonScalar()
scalarness(Int) = NonScalar()
aslist(1) = 1

{% endhighlight %}
</div>

<div class="jupyter-cell">


{% highlight plaintext %}
1
{% endhighlight %}


</div>

All `number` types have the iterate function defined on them.
So we probably want to overwrite that.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
scalarness(::Type{<:Number}) =  Scalar()

@show scalarness(Int);
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
scalarness(Int) = Scalar()

{% endhighlight %}
</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
aslist(1)
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
1-element Array{Int64,1}:
 1
{% endhighlight %}


</div>

Also, **notice that it is now no longer a nice clean static dispatch.**
Because it depends on the global state of the method table.
Which will mean that it has to resolve the trait at run-time.
So it will be slower.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
@code_warntype(scalarness(Dict))
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
Body::Union{NonScalar, Scalar}
│╻╷        hasmethod2 1 ─ %1  = π (Tuple{Dict}, Type{Tuple{Dict}})
││┃│        #hasmethod#19  │   %2  = π (typeof(iterate), Type{typeof(iterate)})
│││╻         signature_type  │   %3  = (Base.getfield)(%1, :parameters)::Core.SimpleVector
││││        │   %4  = π (%3, Core.SimpleVector)
││││        │   %5  = π (%2, Type{typeof(iterate)})
││││        │   %6  = (Core.tuple)(Base.Tuple, %5)::Tuple{DataType,DataType}
││││        │   %7  = π (%4, Core.SimpleVector)
││││        │   %8  = (Core._apply)(Core.apply_type, %6, %7)::Type{Tuple{typeof(iterate),Dict}}
│││╻         getproperty  │   %9  = (Base.getfield)(typeof(iterate), :name)::Core.TypeName
││││        │   %10 = (Base.getfield)(%9, :mt)::Any
│││         │   %11 = π (%8, Type{Tuple{typeof(iterate),Dict}})
│││         │   %12 = $(Expr(:foreigncall, :(:jl_method_exists), Int32, svec(Any, Any, UInt64), :(:ccall), 3, :(%10), :(%11), 0xffffffffffffffff, 0xffffffffffffffff))::Int32
││││╻╷╷╷╷╷    ==  │   %13 = (Core.sext_int)(Core.Int64, %12)::Int64
│││││╻         ==  │   %14 = (%13 === 0)::Bool
││││╻         !  │   %15 = (Base.not_int)(%14)::Bool
│           └──       goto #3 if not %15
│           2 ─       return $(QuoteNode(NonScalar()))
│           3 ─       return $(QuoteNode(Scalar()))

{% endhighlight %}
</div>

Though types that we have defined an explict rule for will still be fast.

However, types that we have an more specific trait method for will still be fast,
since they will not hit the type-unstable fallback.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
@code_warntype(scalarness(Int))
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
Body::Scalar
│1 1 ─     return $(QuoteNode(Scalar()))

{% endhighlight %}
</div>

On a theoretical level, `hasmethod` could be made type-stable and inferable; 
which would allow for the static dispatch that we see for the explict cases.
This might be a thing in future versions of Julia.
It requires triggering recompilations of code depending on the lists of methods when they change.
There is [some discussion of that here.](https://github.com/mauro3/SimpleTraits.jl/issues/40).

## Part 4: Hard-core, reflecting upon `methods`

To avoid the dynamic dispatch that needs to be done for `hasmethod`,
we could declare all the `scalarness` of all types we know to have `iterate` methods.

This can be done could use reflection and metaprogramming,
which will generate a set of trait methods,
based on the current state of the of method table.

Be warned this gets intense.

Notice the methods that exist for iterate: (I'll just show the first five).

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
collect(methods(Base.iterate))[1:5]
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
[1] iterate(v::Core.SimpleVector) in Base at essentials.jl:578
[2] iterate(v::Core.SimpleVector, i) in Base at essentials.jl:578
[3] iterate(ebo::ExponentialBackOff) in Base at error.jl:171
[4] iterate(ebo::ExponentialBackOff, state) in Base at error.jl:171
[5] iterate(m::Base.MethodList, s...) in Base at reflection.jl:730
{% endhighlight %}


</div>

We can extract their parameter types.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
mm = first(methods(Base.iterate))
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
iterate(v::Core.SimpleVector) in Base at essentials.jl:578
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
mm.sig
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
Tuple{typeof(iterate),Core.SimpleVector}
{% endhighlight %}


</div>

Note that that this is not a Tuple **value**, that is a Tuple **type**.
First type-param is the function, and the rest are the arguments.
We are actually going to write dispatch based rules to create out trait functions.


**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
try_get_single_argtype(f::Function) = map(try_get_single_argtype, methods(f)) # check each method of function

try_get_single_argtype(mm::Method) = try_get_single_argtype(mm.sig)

try_get_single_argtype(x::Any) = nothing # Fail, return nothing to indicate failure.

# We are only intrested in doing things for the 1 argument signature.
# which is the 2-tuple
try_get_single_argtype(::Type{Tuple{F, T}}) where {F, T} = T
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
try_get_single_argtype (generic function with 4 methods)
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
try_get_single_argtype(mm)
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
Core.SimpleVector
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
try_get_single_argtype(methods(Base.iterate).ms[2])==nothing
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
true
{% endhighlight %}


</div>

Now we can go through and filter based on if `try_get_single_argtype` returned nothing,

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
is_nothing(::Nothing) = true
is_nothing(::Any) = false

nonscalar_types = unique(filter(!is_nothing, try_get_single_argtype(Base.iterate)))
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
75-element Array{Any,1}:
 Core.SimpleVector                      
 ExponentialBackOff                     
 Base.Iterators.ProductIterator{Tuple{}}
 BitSet                                 
 String                                 
 Base.RegexMatchIterator                
 Base.EnvDict                           
 Cmd                                    
 Base.AsyncCollector                    
 Base.AsyncGenerator                    
 LibGit2.GitBranchIter                  
 LibGit2.GitConfigIter                  
 LibGit2.GitRevWalker                   
 ⋮                                      
 QR                                     
 LinearAlgebra.QRCompactWY              
 QRPivoted                              
 Hessenberg                             
 LQ                                     
 Union{Eigen, GeneralizedEigen}         
 SVD                                    
 GeneralizedSVD                         
 LU                                     
 BunchKaufman                           
 Schur                                  
 GeneralizedSchur                       
{% endhighlight %}


</div>

Notice however some of the types we found are from other modules -- modules that are loaded but not in
a quick hack that lets use exclude those is to check if `occursin(".", string(T))`.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
nonscalar_types = filter(nonscalar_types) do T
    !occursin(".", string(T)) #Quick hack to see if it is in a module that is loaded
end

{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
34-element Array{Any,1}:
 ExponentialBackOff            
 BitSet                        
 String                        
 Cmd                           
 Tuple                         
 Pair                          
 Union{LinRange, StepRangeLen} 
 OrdinalRange                  
 Number                        
 Ref                           
 LinearIndices                 
 Array                         
 BitArray                      
 ⋮                             
 Channel                       
 QR                            
 QRPivoted                     
 Hessenberg                    
 LQ                            
 Union{Eigen, GeneralizedEigen}
 SVD                           
 GeneralizedSVD                
 LU                            
 BunchKaufman                  
 Schur                         
 GeneralizedSchur              
{% endhighlight %}


</div>

Once we have out types we need to generate the code.
The following is a pretty hacky way to do so, abusing strings.
But does give a nice example of dispatch again.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
string_form(T) = string(T)
string_form(T::UnionAll) = string(T.body, " where ", T.var)


function scalarness_function_expr(T)
    str_T = string_form(T)
    parts = split(str_T, "where"; limit=2)
    scalarness_function_expr(parts...)
end


# 1 arg means no where clause
function scalarness_function_expr(type_str::AbstractString)
    type_expr = Meta.parse(type_str)
    
    :(scalarness(::Type{<:$(type_expr)}) = NonScalar())
end

# 2 arg means found a where clause
function scalarness_function_expr(type_str::AbstractString, where_str::AbstractString)
    type_expr = Meta.parse(type_str)
    Meta.parse(string(:(scalarness(::Type{<:$(type_expr)}))) * " where $(where_str) = NonScalar()")
end

{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
scalarness_function_expr (generic function with 3 methods)
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
scalarness_function_expr(BitSet)
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
:(scalarness(::Type{<:BitSet}) = begin
          #= In[41]:16 =#
          NonScalar()
      end)
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
scalarness_function_expr(last(nonscalar_types))
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
:(((scalarness(::Type{<:GeneralizedSchur{Ty, M}}) where M <: (AbstractArray{T, 2} where T)) where Ty) = begin
          #= none:1 =#
          NonScalar()
      end)
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
scalarness_function_expr(nonscalar_types[6])
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
:(((scalarness(::Type{<:Pair{A, B}}) where B) where A) = begin
          #= none:1 =#
          NonScalar()
      end)
{% endhighlight %}


</div>

Looks like good code that we could evaluate.
I know it doesn't capture all cases,
but it is more than enough for demonstration.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
for T in nonscalar_types
    try
        eval(scalarness_function_expr(T))
    catch err
        println()
        @show err
        @show T
        @show scalarness_function_expr(T)
    end        
end
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}

err = TypeError(:<:, "", Type, R<:Tuple{})
T = CartesianIndices{0,R} where R<:Tuple{}
scalarness_function_expr(T) = :((scalarness(::Type{<:CartesianIndices{0, R <: Tuple{}}}) where R <: Tuple{}) = begin
          #= none:1 =#
          NonScalar()
      end)

err = ErrorException("syntax: incomplete: premature end of input")
T = Union{KeySet{#s57,#s56} where #s56<:Dict where #s57, ValueIterator{#s55} where #s55<:Dict}
scalarness_function_expr(T) = :($(Expr(:incomplete, "incomplete: premature end of input")))

err = TypeError(:<:, "", Type, T<:AbstractString)
T = SubString
scalarness_function_expr(T) = :((scalarness(::Type{<:SubString{T <: AbstractString}}) where T <: AbstractString) = begin
          #= none:1 =#
          NonScalar()
      end)

err = ErrorException("syntax: invalid variable expression in \"where\"")
T = BunchKaufman
scalarness_function_expr(T) = :(((scalarness(::Type{<:BunchKaufman{T, S}}) where S <: (AbstractArray{T, 2} where T)) where T) = begin
          #= none:1 =#
          NonScalar()
      end)

{% endhighlight %}
</div>

So, this worked for most of them.
It would be possible to go back and tweak out metaprogramming to catch the last few.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
methods(scalarness)
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-cell">


{% highlight plaintext %}
# 34 methods for generic function "scalarness":
[1] scalarness(::Type{#s11} where #s11<:Union{LinRange, StepRangeLen}) in Main at In[41]:16
[2] scalarness(::Type{#s11} where #s11<:OrdinalRange{T,S}) where {T, S} in Main at none:1
[3] scalarness(::Type{#s11} where #s11<:LinearIndices{N,R}) where {N, R<:Tuple{Vararg{AbstractUnitRange{Int64},N}}} in Main at none:1
[4] scalarness(::Type{#s11} where #s11<:Array{T,N}) where {T, N} in Main at none:1
[5] scalarness(::Type{#s11} where #s11<:BitArray{N}) where N in Main at none:1
[6] scalarness(::Type{#s11} where #s11<:CartesianIndices{N,R}) where {N, R<:Tuple{Vararg{AbstractUnitRange{Int64},N}}} in Main at none:1
[7] scalarness(::Type{#s11} where #s11<:AbstractArray{T,N}) where {T, N} in Main at none:1
[8] scalarness(::Type{#s1} where #s1<:AbstractArray) in Main at In[20]:2
[9] scalarness(::Type{#s11} where #s11<:String) in Main at In[41]:16
[10] scalarness(::Type{#s1} where #s1<:AbstractString) in Main at In[20]:4
[11] scalarness(::Type{#s11} where #s11<:BitSet) in Main at In[41]:16
[12] scalarness(::Type{#s11} where #s11<:AbstractSet) in Main at In[25]:1
[13] scalarness(::Type{#s11} where #s11<:ExponentialBackOff) in Main at In[41]:16
[14] scalarness(::Type{#s11} where #s11<:Cmd) in Main at In[41]:16
[15] scalarness(::Type{#s11} where #s11<:Tuple) in Main at In[41]:16
[16] scalarness(::Type{#s11} where #s11<:Pair{A,B}) where {A, B} in Main at none:1
[17] scalarness(::Type{#s11} where #s11<:Number) in Main at In[41]:16
[18] scalarness(::Type{#s11} where #s11<:Ref{T}) where T in Main at none:1
[19] scalarness(::Type{#s11} where #s11<:NamedTuple{names,T}) where {names, T<:Tuple} in Main at none:1
[20] scalarness(::Type{#s11} where #s11<:Dict{K,V}) where {K, V} in Main at none:1
[21] scalarness(::Type{#s11} where #s11<:AbstractChar) in Main at In[41]:16
[22] scalarness(::Type{#s11} where #s11<:CartesianIndex{N}) where N in Main at none:1
[23] scalarness(::Type{#s11} where #s11<:Channel{T}) where T in Main at none:1
[24] scalarness(::Type{#s11} where #s11<:QR{T,S}) where {T, S<:AbstractArray{T,2}} in Main at none:1
[25] scalarness(::Type{#s11} where #s11<:QRPivoted{T,S}) where {T, S<:AbstractArray{T,2}} in Main at none:1
[26] scalarness(::Type{#s11} where #s11<:Hessenberg{T,S}) where {T, S<:AbstractArray{T,2}} in Main at none:1
[27] scalarness(::Type{#s11} where #s11<:LQ{T,S}) where {T, S<:AbstractArray{T,2}} in Main at none:1
[28] scalarness(::Type{#s11} where #s11<:Union{Eigen, GeneralizedEigen}) in Main at In[41]:16
[29] scalarness(::Type{#s11} where #s11<:SVD{T,Tr,M}) where {T, Tr, M<:(AbstractArray{T,N} where N)} in Main at none:1
[30] scalarness(::Type{#s11} where #s11<:GeneralizedSVD{T,S}) where {T, S} in Main at none:1
[31] scalarness(::Type{#s11} where #s11<:LU{T,S}) where {T, S<:AbstractArray{T,2}} in Main at none:1
[32] scalarness(::Type{#s11} where #s11<:Schur{Ty,S}) where {Ty, S<:(AbstractArray{T,2} where T)} in Main at none:1
[33] scalarness(::Type{#s1} where #s1<:GeneralizedSchur{Ty,M}) where {Ty, M<:(AbstractArray{T,2} where T)} in Main at none:1
[34] scalarness(::Type{T}) where T in Main at In[27]:2
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
@show scalarness(Dict{Int,Int})
@show scalarness(typeof([1,3,2]'))
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
scalarness(Dict{Int, Int}) = NonScalar()
scalarness(typeof(([1, 3, 2])')) = NonScalar()

{% endhighlight %}
</div>

<div class="jupyter-cell">


{% highlight plaintext %}
NonScalar()
{% endhighlight %}


</div>

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
@code_warntype scalarness(typeof([1,3,2]'))
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
Body::NonScalar
│1 1 ─     return $(QuoteNode(NonScalar()))

{% endhighlight %}
</div>

So we have done this,
and generated a ton of methods.
And we avoid doing a dynamic dispatch on `hasmethod`,
except as a fallback,
for types that were not loaded when our metaprogramming run.
A function could be exposed to rerun this.

The whole thing of metaprograming over reflection is kinda evil though.
But it is perhaps interesting to see how it can be done.
