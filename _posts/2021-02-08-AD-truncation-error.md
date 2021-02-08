---
title: Automatic Differentiation Does Incur Truncation Errors (kinda)
layout: default
tags:
   - julia, julia-lang, AD, autodiff
---

Griewank and Walther's 0th Rule of algorithmic differentiation (AD) states:

> Algorithmic differentiation does not incur truncation error.

([2008, "Evaluating Derivatives: Principles and Techniques of Algorithmic Differentiation", Andreas Griewank and Andrea Walther.](https://dl.acm.org/doi/book/10.5555/1455489))


In this blog post I will show you a case that looks like it does in fact incur truncation error.
Though this case will arguably be a misinterpretation of that rule.
This blog post will thus highlight why careful interpretation of the rule is necessary.
Further it will motivate why we need to often add more custom sensitivity rules (custom primitives) to our AD systems, even though you can AD anything with just a few basic rules. 

Credit to [Mike Innes](https://mikeinnes.github.io/) who pointed this out to me at JuliaCon 2018.
<!--more-->

## 1. Implement an AD, for demonstration purposes

We will start by implementing a simple forwards mode AD.
This implementation is based on [ForwardDiffZero from the ChainRules docs.](https://juliadiff.org/ChainRulesCore.jl/dev/autodiff/operator_overloading.html#ForwardDiffZero), but without ChainRules support.
Though it is also the simplest most stock-standard implementation once can conceive of.


```julia
struct Dual <: Number
    primal::Float64
    partial::Float64
end

primal(d::Dual) = d.primal
partial(d::Dual) = d.partial

primal(d::Number) = d
partial(d::Number) = 0.0

function Base.:+(a::Union{Dual, T}, b::Union{Dual, T}) where T<:Real
    return Dual(primal(a)+primal(b), partial(a)+partial(b))
end

function Base.:-(a::Union{Dual, T}, b::Union{Dual, T}) where T<:Real
    return Dual(primal(a)-primal(b), partial(a)-partial(b))
end

function Base.:*(a::Union{Dual, T}, b::Union{Dual, T}) where T<:Real
    return Dual(
        primal(a)*primal(b),
        partial(a)*primal(b) + primal(a)*partial(b)
    )
end

function Base.:/(a::Union{Dual, T}, b::Union{Dual, T}) where T<:Real
    return Dual(
        primal(a)/primal(b),
        (partial(a)*primal(b) - primal(a)*partial(b)) / primal(b)^2
    )
end

# needed for `^` to work from having `*` defined
Base.to_power_type(x::Dual) = x


"Do a calculus. `f` should have a single input."
function derv(f, arg)
    duals = Dual(arg, 1.0)
    return partial(f(duals...))
end
```

We can try out this AD and see that it works.
```julia
julia> foo(x) = x^3 + x^2 + 1;

julia> derv(foo, 20.0)
1240.0

julia> 3*(20.0)^2 + 2*(20.0)
1240.0
```

## 2. Implement Sin and Cos, for demonstration purposes

Now we are going to implement the `sin` and `cos` functions for demonstration purposes.
[JuliaLang has an implementation of `sin` and `cos` in Julia](https://github.com/JuliaLang/julia/blob/v1.5.3/base/special/trig.jl), that could be ADed though by a source to source AD (like [Zygote.jl](https://github.com/FluxML/Zygote.jl)).
But because it is restricted to `Float32` and `Float64` an operator overloading AD like ours can't be used with it.
That's Ok we will just code up a simple one using Taylor polynomials.
we know that eventually the code run does have to look something like this, since all operations are implemented in terms of `+`, `*` and `^`, `/`, bit-shifts and control-flow.
(Technically [x86 assembly](https://en.wikipedia.org/wiki/X86_instruction_listings#Added_with_80387) does have a primitive for `sin` and `cos` but as far as I know no LibM actually uses them. There is a [discussion of why LLVM](https://reviews.llvm.org/D36344) doesn't ever emit them if you go looking)
The real code would include control flow to wrap around large values and stay close to zero, but we can skip that and just avoid inputting large values.

So using Taylor polynomials of degree 12 for each of them:

```julia
my_sin(x) = x - x^3/factorial(3) + x^5/factorial(5) - x^7/factorial(7) + x^9/factorial(9) - x^11/factorial(11)  # + 0*x^12

my_cos(x) = 1 - x^2/factorial(2) + x^4/factorial(4) - x^6/factorial(6) + x^8/factorial(8) - x^10/factorial(10) + x^12/factorial(12)
```

Check the accuracy
we know that  `sin(π/3) == √3/2`, and that `cos(π/3) == 1/2`
(not that yes, π is an approximation here but it is a very accurate one. And doesn't change the result that follows.)
```julia
julia> my_sin(π/3)
0.8660254034934827

julia> √3/2
0.8660254037844386

julia> abs(√3/2 - my_sin(π/3))
2.9095592601890985e-10

julia> my_cos(π/3)
0.5000000000217777

julia> abs(0.5 - my_cos(π/3))
2.177769076183722e-11
```

This is not terrible.
`cos` is slightly than `cos` 
We have a fairly passable implementation of `sin` and `cos`.

## 3. Now lets do AD.

We know the derivative of `sin(x)` is `cos(x)`.
So if we take the derivative of `my_sin(π/3)` we should get `my_cos(π/3)≈0.5`.
_It should be as accurate as the original implementation, right?_
because Griewank and Walther's 0th Rule:

> Algorithmic differentiation does not incur truncation error.

```julia
julia> derv(my_sin, π/3)
0.4999999963909431
```
Wait a second.
That doesn't seem accurate, we expected 0.5, or at least something pretty close to that.
`my_cos` was accurate to $2 \times 10^{-11}$.
`my_sin` was accurate to $3 \times 10^{-10}$
How accurate is this:
```julia:
julia> abs(derv(my_sin, π/3) - 0.5)
3.609056886677564e-9
```

What went wrong?

## 4. Verify

Now, I did implement an AD from scratch there.
So maybe you are thinking that I screwed it up.
Lets try some of Julia's many AD systems then.

```julia
julia> import ForwardDiff, ReverseDiff, Nabla, Yota, Zygote, Tracker, Enzyme;

julia> ForwardDiff.derivative(my_sin, π/3)
0.4999999963909432

julia> ReverseDiff.gradient(x->my_sin(x[1]), [π/3,])
1-element Vector{Float64}:
 0.4999999963909433

julia> Nabla.∇(my_sin)(π/3)
(0.4999999963909433,)

julia> Yota.grad(my_sin, π/3)[2][1]
0.4999999963909433

julia> Zygote.gradient(my_sin, π/3)
(0.4999999963909433,)

julia> Tracker.gradient(my_sin, π/3)
(0.4999999963909432 (tracked),)

julia> Enzyme.autodiff(my_sin, Active(π/3))
0.4999999963909432
```

Ok, I just tried **7** AD systems based on totally different implementations.
I mean [Enzyme](https://github.com/wsmoses/Enzyme.jl/) is reverse mode running at the LLVM level.
Totally different from [ForwardDiff](https://github.com/JuliaDiff/ForwardDiff.jl) which is the more mature version of the forward mode operator overloading AD I coded above.
Every single one agreed with my result, up to [1 ULP](https://en.wikipedia.org/wiki/Unit_in_the_last_place).
I think that last digit changing is probably to do with order of addition (IEEE floating point math in funky), but that is another blog-post.
So I think we can reliably say that this is what an AD system will output when asked for the derivative of `my_sin` at `π/3`.

## 5. Explanation

Why does AD seem to be incurring truncation errors?
Why is the derivative of `my_sin` much less accurate than `my_cos`?

The AD system is (as you might have surmised) not incurring truncation errors.
It is giving us exactly what we asked for, which is the derivative of `my_sin`.
`my_sin` is a polynomial.
The derivative of the polynomial is:
```julia
d_my_sin(x) = 1 - 3x^2/factorial(3) + 5x^4/factorial(5) - 7x^6/factorial(7) + 9x^8/factorial(9) - 11x^10/factorial(11)
```
which indeed does have
```julia
julia> d_my_sin(π/3)
0.4999999963909432
```
`d_my_sin` is a lower degree polynomial approximation to `cos` than `my_cos` was, so it is less accurate.
Further, you can see that while n-derivative of `sin` is always defined as `sin(x+n*π/2)`, as we keep taking derivatives of the polynomial approximations terms keep getting dropped.
AD is making it smoother and smoother til it is just a flat `0`. 

The key take away here is that _the map is not the territory_.
Most nontrivial functions on computers are implemented as some function that that approximates (_the map_) the mathematical ideal (_the territory_).
Automatic differentiation gives back a completely accurate derivative of the that function (_the map_) doing the approximation.
_Furthermore, the accurate derivative of an approximation to the idea (e.g `d_my_sin`), is less accurate than and approximation to the (ideal) derivative of the ideal (e.g. `my_cos`)._

So what do?
Well-firstly, do you want to do anything?
Maybe the derivative of the approximation is more useful.
(I have been told that this is the case for some optimal control problems).
But if we want to fix it can we?
Yes, the answer is to insert domain knowledge, telling the AD system directly what the approximation to the derivative of the ideal is.
The AD system doesn't know its working with an approximation, and even if it did, it doesn't know what the idea it is approximating is.
The way to tell it is with a custom primitive i.e. a custom sensitivity rule.
This is what the ChainRules project in Julia is about, being able to add custom primitives for more things.


Every real AD system already has a primitive for `sin` built in
(which is one of the reasons I had to define my own above).
but it won't have one for every novel system you approximate.
E.g. for things defined in terms of differential equation solutions or other iterative methods.

We can define in our toy AD at the start this custom primative via:
```julia
function my_sin(x::Dual)
    return Dual(my_sin(primal(x)), partial(x) * my_cos(primal(x)))
end
```
and it does indeed fix it.
```julia
julia> derv(my_sin, π/3)
0.5000000000217777

julia> abs(derv(my_sin, π/3) - 0.5)
2.177769076183722e-11
```

### Bonus: will symbolic differentiation save me?

Probably, but probably not in an interesting way.
Most symbolic differentiation systems will have a rule just like the custom primitive for `sin` built in.

But potentially one built for a suitably weird language could be using representation of `sin` that is a lazily evaluated polynomial of infinite degree underneath.
And in that case there is a rule for its derivative, expressed in terms of changes to its coefficient generating function; which would also give back a lazily evaluated polynomial.
I don't know if anyone does that though; I suspect it doesn't generalized well.
Further, for a lot of things you want to solving systems via iterative methods, and these work for concrete numbers not lazy terms.
Maybe there is a cool solution though, I have no real expertise here.
Symbolic differentiation in general has problems scaling to large problems.