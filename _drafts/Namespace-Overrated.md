---
title: Namespaces are overrated -- let's do less of those!
tags: julia
---

The Python people say:
[_"Namespaces are one honking great idea -- let's do more of those!"_](https://www.python.org/dev/peps/pep-0020/).
When it comes to julia though, I'ld have to disagree.
To be more specific: _**module** namespaces are overrated**_.
I have no problem with local namespaces e.g. function scope, they are great.
But _**submodules** -- let's do less of those_,
and using a namespace someone else declared, like _**FooBase.jl** -- let's do more of that_.

<!--more-->

People coming from other languages to julia sometimes use a lot of submodules.
I know I did.
For a variety of reasons this leads to small bundle of pain,
and misses out on opportunities to make the code easy to generalise later.


## Pain Points
In short the pain points:

### Submodules are not scoped within their parent modules namespace.

For example

```julia
module Foo
	export fooit()
	function fooit()
		println(“It was Fooed”)
	end
	
	module Bar
		export barit()
		function barit()
			fooit()
			println(“and it was Barred”)
		end
	end
end
```

Calling `Foo.Bar.barit()` will give an error that `fooit` is not defined.
Because a submodule does not inherit the scope of its parent’s namespaces.

Instead you have do do womething lime

```julia
module Foo
	function fooit()
		println(“It was Fooed”)
	end
	
	module Bar
		using .. # or one of the other import/using varients
		function barit()
			fooit()
			println(“and it was Barred”)
		end
	end
end
```

So essentially being a submodule give you no special privileges with regards to your parent module, except beyond the special syntax for accessing your parent via `using ..` (etc).

The converse is also largely true.
While the submodule is Loaded into a name (`Bar` in this case) in the parent’s scope, it does not bring in any of the names – not even the exported ones.
For `barit()` to be called from the `Foo` namespace, you either need to do a `using Bar` first, or access it via the namespace `Bar.barit()`.


By making a submodule you are the essentially saying that this is a separate self-contained piece of code.
It’s dependencies on the parent are explicitly stated (via `using` etc), and it’s parent’s dependencies are on it are explicitly stated (again via `using` etc).
At that, point why is it even in the same Package? Might as well just make another package outright.
This is the approach perhaps most notably taken by the DiffEq ecosystem.
[LINK TO DIFFEQ.ORG].
It is up to [FILL NUMBER HERE] and counting packages.
The original set of packages it started with were mostly submodules of DifferentialEquations.jl.
Breaking them up into one module per package simplfies things.
Further it gives each their own space to track issues etc;
and cuts down on the dependency chains, which can be pretty huge.
Downloading the entire package is some high hundred of thousands of lines of code now, with support for more DiffEq things than most engineers have even heard of. (Poor simple engineers like me have nothing on applied maths majors. :-P)

Staying one-to-one correspondence with packages and modules is keeps you on the tried and true path. Sometimes people forget that there is even a difference. [LINK TO STACKOVERFLOW POST HERE].

As a digression, (and this really could be another blog post), all julia projects should be setup as packages. Even they are just a simulation/analytics script. Being a package gives you the best tools (like using PkgDev.jl etc to setup CI testing.); and again it is just the more well explored path.


### Things can get weird if you load a submodule both directly and via it’s parent











