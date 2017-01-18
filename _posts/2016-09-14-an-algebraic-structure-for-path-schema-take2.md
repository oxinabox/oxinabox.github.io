---
title: An Algebraic Structure For Path Schema (Take 2)
layout: default
---
$$\newcommand{\abs}[1]{\lvert#1\rvert}$$
$$\newcommand{\(}{\left(}$$
$$\newcommand{\)}{\right)}$$

This is a second shot at expressing Path Schema as algebraic objects.
See [my first attempt]({{ site.url }}/2016/09/11/an-algebraic-structure-for-path-schema.html).
The definitions should be equivelent, and any places they are not indicates a deficency in one of the defintions. This should be a bit more elegant, than before. It is also a bit more extensive.
Note that $$R$$ and $$A$$ are now defined differently, and $$A^\ast$$ and $$R^\ast$$ are what one should be focussing on instead, this is to use the free monoid convention.


In general a path can be described as a a *hierachical index*, onto a *directed multigraph*. Noting that "flat" sets, trees, and directed graphs are all particular types of directed multigraphs. 

To repeat the introduction:

>This post comes from a longish discussion with Fengyang Wang
>(@TotalVerb), on the [JuliaLang Gitter](https://gitter.im/JuliaLang/julia). Its pretty cool stuff.



> It is defined here independent of the object (filesystem, document etc) being indexed. The precise implementation of the algebric structure differs, depending on the Path types in question, eg Filesystem vs URL, vs XPATH.


> This defintion is generally applicable to paths, such as:
> 
>  - File paths
>  - URLs
>  - XPath
>  - [JSON paths](https://www.playframework.com/documentation/2.1.1/ScalaJson#Accessing-Path-in-a-JSON-tree)
>  - Apache ZooKeeper Paths
>  - Swift Paths (Server/Container/Psuedofolder/Object)
>  - Globs

> The defintion whch follows provides all the the expected functionality on paths

<!--more-->

* Table of Contents
{:toc}

## Definition
To have the general functionality of a path we only need to define a few items on our index, from these the rest of the functionality flows. This sets a minimal amount of functionality for a path at the most abstract level. Particular path implementations can provide more. The defintion is made from 3 object $$A$$, $$R$$, $$\cdot$$, with 3 rules **(1)**, **(2)**, **(3)** binding them.

Our path is defined by two sets, $$R$$, and $$A$$, and an operation $$\cdot$$.

 - We call $$R$$ the set of _relative path components_.
 - $$A$$ the set of _absolute path roots_.
  - $$\cdot$$ is called the `pathjoin` operator.
    - By convention $$\cdot$$ acts on the right.
 -  **(1)** It is required that $$\cdot$$ generates a free monoid $$\(R^\ast,\cdot\)$$ from $R$
   - We will call the identity element of this monoid $$I_R$$.
     - We will also call this the _relative path root_, and call $$A \cup\{I_R\}$$ the _roots_ of the path schema
   - For convience we will follow the usual definition of $$R^+ = R \setminus {I_R\}$$
 - **(2)** It is also required that $$A$$ is disjoint from $$R$$
 - **(3)** It is required that $$\(R^\ast,\cdot\)$$ acts faithfully, on $$A$$ 
  - We call the closure of $$A$$ under $$R^\ast$$,  $$A^\ast$$.
   - By the associativity of $$R$$, we know $$A^\ast = \{a \cdot x   \mid \forall a \in A,\; \forall x \in R^\ast\}$$
   - From this, and from the faithfulness of $$R$$ on itself (as a free monoid), we know that $$R$$ acts faithfully on all of $$A^\ast$$
   - We will also define here for convience: $$A^+ = A^\ast\setminus A = \{a \cdot x \mid a \in A,\; x \in R^+\}$$
 - Note that $$A^\ast$$ is not defined to act with the $$\cdot$$ operator on $$A$$ or on $$R$$; and further we suggest that if $$A$$ does in a particular implemention do so, then $$A$$ is likely misdefined.

### Number of roots
Depending on the system being indexed, there may be one or more abolute roots.
In linux file systems, there is one root `/`.
In windows, there is one root per hard drive `C:`, `D:` etc, plus a an additional root for named pipes `\\.\pipe\`.
One also might wish to consider UNC paths to be part of the same system in windows -- these to would have there on roots.

In theory we could also have zero absolute path roots -- this would mean there are on absolute paths. However this is not generally useful, as the evaluation function given later, to resolve an index into the object is only defined for absolute paths.

## Parentdir, and basename
As the path is a heirachical index, every point in the heirachy has a parent, or is a root.

We define a function $$p:\; A^\ast \cup R^\ast \to A^\ast \cup R^\ast$$. This is called the `parentdir` function. Note the similarity to Lisp's `cdr`, or the _tail_ operation.

 - for nonroots: $$\forall x \in A^+ \cup R^\ast, \; \forall r\in R$$ we have: $$p:\; x \cdot r \mapsto x$$
 - for roots: $$\forall x\in A\cup \{I_R\}$$ we have: $$p:\; x \mapsto x$$

It takes a little to show that this is properly a function, but it comes from the faithfulness of $$R$$.
Note that $$p(A^\ast)=A$$ and $$p(R^\ast)=R^\ast$$, and that these as disjoint.


We define another a function $$b:\; A^\ast \cup R^\ast \to A \cup A$$. This is called the `basename` function. Note the similarity to Lisp's `car`, or the _head_ operation.

 - for nonroots: $$\forall x\in A^+\cup R^\ast,\; \forall r\in R$$ we have: $$b:\; x \cdot r \mapsto r$$
 - for roots: $$\forall x\in A\cup \{I_R\}$$ we have: $$b:\; x \mapsto x$$

Note that for nonroots, the resault is always (and covers every) path componant -- that is to say $$b(A^\ast)=R$$.
And for roots, this is the identity.
We note that $$b(x)=x \Leftrightarrow p(x)=x \Leftrightarrow x\; is\; \;a \; root$$

$$p$$ and $$b$$ are linked.
In that: $$\forall x \in A^\ast \cup R^\ast \; p(x) \cdot b(x) = x$$.
This can probably be related to a kind of pseduo-inverse.

### Parentdir and $$\varphi$$ (`..`)
As a digression:
In many implementations of paths, it may be tempting to define an element $\varphi \in R$ and state that $$p(x) = x\cdot \varphi$$.
Eg in filepaths this would be `..`. However this is not possible, under the above definition of a path, as then $$ \left( R,\cdot \right) $$ would no longer be a free monoid, or indeed a monoid at all. As $$I_R \cdot \varphi = \varphi$$ by the fact that $$I_R$$ is the identity; but $$p(I_R)= I_R$$ by definition of $$p$$. Depending on how this is resolved one might end up with for `pathjoin(a, ./..)==a`.
A alternative is to define a normalisation function (or a equalience relation), that resolves this; as we will do later.

## Derived Operations

### the _root_ function

We define a function to find the root of a path. $$root:\; A^\ast \cup R^\ast \to A\cup\{I_R\}$$

- if $$p(x)!=x$$  then $$root:\; x -> p(x)$$
- if $$p(x)=x$$ then $$root:\; x -> x$$

The root of an element of $$R^\ast$$ is always $$I_R$$; and of an element of $$A^\ast$$ is always an element of $$R$$.

To make finding roots fast (as it is useful for the *relative_to* operation) it seems efficent to always store an element of $$A^\ast$$, as its root (an element of $$A$$), and a relative path from that root (an element of $$R^\ast$$; which we will call the relative compent of the absolute path). We know that all absolute paths can be expressed this way, due to the faithfulness of $$R$$.

### the _depth_ function

We define a function  $$d:\; A^\ast \cup R^\ast \to \mathbb{N}_0)\$$ <!--_-->, often call _depth_ or *nesting level*.

 - for roots  $$r\in A\cup \{I_R\}$$, $$d:\; r\mapsto 0$$
 - for nonroots $$x\in A^+\cup R^+$$ $$d:\; x\mapsto n$$ for $n$ the smallest integer, such that $$p^n(x)\in A\cup \{I_R\}$$
 
### the _parts_ function
We define a funtion to find the parts of a path.
This breaks a path down in to a sequence starting with it's root, and followed by path componants

- $$parts:\; A^\ast \cup R^\ast \to \(A \cup R\) \times \(R\)^{\mathbb{N}_0}$$ <!--_-->
- $$parts:\; x\mapsto (a_i)^{d(x)}_{i=0})$$ <!--_-->
- \$$a_{d(x)}=b(x)$$
 - otherwise $$a_i = p^{d(x) - i}(x)$$
 - this ends with $$a_0 = root(x) $$

We can recombine the path components: for product over $$\cdot$$ by $$x=\prod_{p\in parts(x)} p$$.<!--_-->

Notice this option (like all the other really), can be implemented easily, by implementing it for the $$R^\ast$$ and then apply it to the relative component of a absolute path, until it reach the root -- and then subsituting the absolute root for $$I_R$$.


### the _within_ function
$$within$$, takes two paths, with one inside the other and finds the relative path from the second to the first.
It is a weaker version of $$relative_to$$

 - \$$within:\; (A^\ast \cup R^\ast)\times(A^\ast \cup R^\ast) \to R^\ast$$
 - for $$within(x,y) = z$$  we say "the path of $$x$$, within $$y$$ is $$z$$"
 - let $$parts(x) = (x_0, ... x_{d(x)}$$
 - let $$parts(x) = (y_0, ... y_{d(y)}$$  <!--_--> 
 - $$within(x,y)$$ is defined only if $$d(x) > d(y)$$ and $$\forall 0\le i \le d(y) \; x_i=y_i$$
   - note that this means they must share a common root.
 - then for $$within:\; (x, y) \mapsto \prod^{j=d(x)}_{j=d(y)+1} x_j$$
 

## Resolving a Path to the object 
Finally we have an the operation that turns a absolute path ($$x\in A$$) into a entity, or a set of entities from the Domain being indexed $$D$$. These operations are less clear, as at this level objects must be considered -- the data store (the indexed set) must be accessed to resolve. And issues like symlinks, hardlinks,  etc start to matter (To use examples from POSIX filepaths).

- we define $$e:\; A^\ast \to \mathcal{P}(D)$$ to evaluate the path
- For $$x_1, x_2 \in A$$,  $$x_1=x_2 \Rightarrow e(x_1) == eval(x_2)$$
  - that is to say $$e$$ is indeed a function.
  - Note that the implication is one way, that is to say: there can be multiple paths $$y_1, y_2 \in A^\ast$$ such that $$y_1\neq y_2$$ but $$e(y_1)=e(y_2)$$

 
Depending on the type of path schema, this may be 1 enitity, or many

- We call path schema with paths that can eval to any nymber of entities MultiPaths Schemas
   - eg XPATH or Glob
 - We call Path schema with paths which always eval to one or zero entities MonoPath Schemas
  - eg URL, POSIX / NT File System paths
  - In these case, we can define $$\epsilon(\bar{A}^\ast) \to D$$. 
    - Where $\bar{A}^\ast$ is the restriction of $A$ to paths that exis. 
    - That is $$\bar{A}^\ast = \{a \; \mid\; \abs{e(a)}=1 \}$$

Either way we can make some statements about the cardinality of $$e(x)$$

- \$$\abs{e(p(x))} \le \abs{e(x)}$$ 
 - \$$\abs{e(x)} > 0  \Rightarrow \abs{e(p(x))} > 0$$
  - or its (perhaps more interesting) contra-positive: $$\abs{e(p(x))}=0 \Rightarrow \abs{e(x)}=0$$
  - for MonoPaths we thus have if $$\epsilon(x)$$ is defined then $$\epsilon(p(x))$$ is defined.  

## $$\varphi$$ the Pseudoparent Element
This was touched on before, that for many systems we would like to have a element $$\varphi$$, that acts like a the parentdir function. But we can't because it would break the monoid. Now that we have a understanding of evaluating a path to a domain object, it starts to make most sense to talk of this. 
This $$\varphi$$ is not defined for all Path Schema, but it is for many (For file paths it is `..`).
Where it exists:

We define $$\varphi\in R$$, as having the property that: 
$$\forall x \in A^\ast\;$$ then $$e(x\cdot \varphi) = e(p(x))$$.

#### Does $$\varphi$$ even exist? (POSIX compliance)

Note that for POSIX filesystems using $$\varphi = \mathtt{..}$$ this is not [POSIX compliant](http://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap04.html#tag_04_12),  as POSIX requires that Symlink directories are substituted in to the path, before `..` (our $$\varphi$$) is resolved.
Our $$p$$ function does not have that requirement.
As far as I know there is no way to be POSIX complient on the behavour of `..` without actually reading the filesystem; to know what is or is not a symlink.

See [this Unix Stack Exchange question](http://unix.stackexchange.com/questions/310008/) for more information.

The behavour here is the default behavour in [Bash. ksh, zsh and ash](http://unix.stackexchange.com/questions/11044), with the `-L` flag (which is on by default for `cd` and off by default for `pwd`). Also in python `os.path`, and Node.jl's `path`.

[Python3 pathlib](https://docs.python.org/3/library/pathlib.html), has the correct behavour -- in that it does not process `..` at all, except in the final resolve step. i.e. it does not offer any of the following functionality except a final resolve for absolute paths (Their $$relative\_to$$ is the $$within$$ defined ealier). The [Haskell Path Package bans](https://hackage.haskell.org/package/path) `..` outright.

This gets particular hairy for Multipaths; which have path components that are more complex than simply directories.
Consider for a Glob: $$\mathtt{a/**/b/..}$$ finds all folders below `a` with a sibling that is named `b`.
Where as $$p(\mathtt{a/**/b})=\mathtt{a/**}$$ which finds all folders below `a`.
And so `..` is not $$\varphi$$ for Glob paths, and indeed there is no such element for them.


So not supporting funtions involving $$varphi$$ may be a good idea for an implementation. Without it though you can not have $$norm$$ nor $$relative_to$$.
Except by accessing the backing system.


### Normalising, to remove $$\varphi$$
Using this, and we can now define a normalising function that removes the $$\varphi$$ where possible.

 - $$norm:\; A^\ast \cup R^\ast \to A^\ast \cup R^\ast$$.
 - This has the requirement that $$\forall a\in A^\ast$$ then $$e(norm(a))=e(a)$$.
 - And for $$\forall r\in R^\ast$$ and $$\forall a\in A^\ast$$ then $$e(a\cdot r)=e(a\cdot norm(a))$$.

The function we will define removes all instances of $$\varphi$$ from absolute paths (elements of $$A^\ast$$),
and all non-leading instances from relative paths (elements of $$R^\ast$$) -- though some nonleading $$\varphi$$s will potentenitally become leading.

We consider this on parts the relative componant of the path. That is $$parts(within(x,root(x)))$$ (which is just $$x$$ if $$x \in R^\ast$$)
In this we repeatedly replace: from the left the earliest occurances of $$\left[ x,\varphi, y\right]$$ with $$\left[ y \right]$$, where $$x \in R \setminus {\varphi}$$, and $$y\in R$$.
If it were a relative path, then this all we have to do, we simply rejoin the rewritten paths, and it is done.
If it is applied to a absolute path, then we then can strip all leading instances of $$\varphi$$, since $$\forall a \in A$$, $$e(a \cdot \varphi) = e(p(a)) = e(a)$$.

The replacement rule method is quite easy to explain in words.
But rather awkward to write mathematically.

To supplement it for clarity, see the implementation, of `normparts` in this [Julia, Jupyter Notebook](http://nbviewer.jupyter.org/gist/oxinabox/3593341867bc31131a92fd38d5387353).

Proving that $$norm$$ does have the features we import upon it, with regard to not changing what paths point to, is not done here. Indeed I am yet to do so at all. It seems like to be very involved.

Note that even if for some $$x,\; y \in A \cap R^\ast$$ with  $$norm(x) = norm(y)$$, this still does _not imply_ that $$e(x) \neq e(y)$$, as other things, eg POSIX symlinks, can still give multiple paths, to the same domain object.

### The *relative_to* function

Earlier we saw the $within$ function; which could find the relative path of one directory, within the other.
But this was limitted, as we could not move up the heirachy.
Now using $$\varphi$$ we can.

$$relative\_to$$, takes two paths, and finds the relative path from the second to the first.

 - \$$relative\_to\; (A^\ast \cup R^\ast)\times(A^\ast \cup R^\ast) \to R^\ast$$
 - for $$relative\_to(x,y) = z$$  we say "the path of $$x$$, relative to $$y$$ is $$z$$"
 - let $$parts(x) = (x_0, ... x_{d(x)}$$
 - let $$parts(x) = (y_0, ... y_{d(y)}$$   
 - $$relative\_to(x,y)$$ is defined only if $$root(x)=root(y)$$, i.e $$x_0=y_0$$ <!--_-->

 - let $$s\in \mathbb{N}_0$$, with $$0\le s \le min(d(x),d(y))$$,  
 such that $$\forall t\in \mathbb{N}_0\: 0 \le t \le s $$, $$x_t=y_t$$  <!--_-->
   - $$s$$ is the common path length
 - then $$relative\_to(x,y) =  \prod_{i=0}^{i=d(y)-s} \varphi \; \cdot \; \prod_{i=s}^{i=d(x)} x_i\ $$
   - note that the first part of this is equal to $$I_R$$ if $$d(y)<s$$  <!--_-->

And with this: $$norm(y \cdot relative\_to(x,y)) = norm(x)$$. <!--_-->
And $$e(y \cdot relative\_to(x,y)) = e(x)$$. 
(proving that, also looks like it would be very *fun*, and is not done here).

As suggeted before, if $$\varphi$$ is not defined to meet $$e(x \cdot \varphi) = e(p(x))$$, and thus $$norm$$ is not defined, we can still define the properties of $$relative_to$$
If we do not have 


## Other extensions

### Canonical  Name
Some path schema do actually permit a canonical name.
In these schema $$\forall x,y \in A^\ast\; e(x)=e(y) \Leftrightarrow x=y$$ 
Swift Object Stores are one such path system which permit a canonical name.


### Differenciating Directory Path from File Paths

We have differenciated Absolute Paths from Relative Paths, it is also possible to differenciate File paths from Directory Paths.
This is done in the [Haskell Path package](https://hackage.haskell.org/package/path).
This places restictions on *pathjoin* ($$\cdot$$).
For $R_F^\ast\subset R^\ast$ the relative file paths, and for $A_F^\ast\subset A^\ast$ the set absolute file paths.
For $R_D^\ast=\subset R^\ast = R^\ast \setminus R_F^\ast$ the set of relative directory paths, and for $$A_F^\ast\subset A^\ast = A^\ast \setminus A_F^\ast$$
then only the following joins are permitted, and they have the following results:

 - \$$A_D^\ast \times R_F^\ast \to A_F^\ast$$
 - \$$R_D^\ast \times R_F^\ast \to R_F^\ast$$
 - \$$R_D^\ast \times R_D^\ast \to R_D^\ast$$
 - \$$A_D^\ast \times R_D^\ast \to A_D^\ast$$

This stops $$R$$ from being a monoid, but $$R_D$$ is still a free monoid.
The earlier definitions can be rewritten again, to take this into account, though it does add considerable complexity.
We replace all uses of $$R^\ast$$ with uses of $R_D^\ast$, paired with $R_F$.
<!--_-->

## Conclusion

So that is paths. This is a highly abstract set of features.
We show that from the simple rules we can get complex functionality, that is applicable accross the wide range of pathing systems
It is applicable on all kinds of things, from key-values stores to XPATH.
Most importantly perhaps, it covers URLs and Filepaths.

In general one might think monopath schema with only as single absolute root, are isomorphic to strings.
This is true, but it is important to note the size of the alphabet -- which for most path schema in use is countable infinite.

We did not prove any of our assertions, here.
And indeed I've not written out proof for many of them at all.
I hope however this was illuminating.


### See also:

 - [PEP 428 -- The pathlib module -- object-oriented filesystem paths](https://www.python.org/dev/peps/pep-0428/)
 - [Why pathlib.s not inherit from String](http://www.snarky.ca/why-pathlib-path-doesn-t-inherit-from-str)

