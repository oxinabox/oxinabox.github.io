---
title: An Algebraic Structure For Path Schema
layout: default
---
$$\newcommand{\abs}[1]{\lvert#1\rvert}$$

This post comes from a longish discussion with Fengyang Wang
(@TotalVerb), on the [JuliaLang Gitter](https://gitter.im/JuliaLang/julia). Its pretty cool stuff.

In general a path can be described as a a heirachical index.
It is defined here independent of the object (filesystem, document etc) being indexed. The precise implementation of the algebric structure differs, depending on the Path types in question, eg Filesystem vs URL, vs XPATH.


This defintion is generally applicable to paths, such as:

 - File paths
 - URLs
 - XPath
 - [JSON paths](https://www.playframework.com/documentation/2.1.1/ScalaJson#Accessing-Path-in-a-JSON-tree)
 - Apache ZooKeeper Paths
 - Swift Paths (Server/Container/Psuedofolder/Object)
 - Globs

The defintion whch follows provides all the the expected functionality on paths

<!--more-->

## Definition Path Schema:

 - $$A$$ a set of absolute paths
 - $$R$$ a set of relative paths
 - $$A$$ and $$R$$ are disjoint
 - $$(R, \cdot)$$ a monoid
   - $$\cdot$$ is the called `pathjoin` operation
   - $$(R, \cdot)$$ faithfully acts on $$A$$ and also on $$R$$ from the right
   - we denote the  identity $$I_R \in R$$  (For filesysystem/URL paths this is `.`)
 - $$p$$ an operator, called the `parentdir` operation
   - \$$p:\; A\to A$$
   - \$$p:\; R\to R$$
   - In filesystem/URL paths this is often similar to applying the Relative path `..`, but with some exceptions.
      - For example `parentdir(.)=.` $$\neq$$ `./..` (See below).
 - $$b$$ an operator, called the `basename` operation
   - \$$b:\; A\cup R \to R$$ 
 - $$\forall(x) \in  A\cup R$$ $$p(x) \cdot b(x) = x$$
   - That is to say, `pathjoin(parentdir(x), basename(x)) == x`
 - \$$\forall r \in A \cup R \wedge p(r)=r \Leftrightarrow b(r)=I_R$$
   - and we call such elements $$r$$ roots
 - $$\forall x \in A \cup R, \exists n \in \mathbb{N}: s.t. p^n(x) = p^{n-1}$$ -- a root
 - $$I_R$$ is the only root in $$R$$
 - There exist at least one root in $$A$$
   - In unix filesystems, this is `/`
   - In windows, this is each drive name `C:`,`D:` etc, and a global `//` for names pipes and UNC paths
   - For URLs this is the domain name.


## Derived Operations:
From this we can define additional operations:

 - $$root:\; A \cup R \to A \cup R $$ that finds the root of the path.
   - $$root(x)=r$$ for $$r:=\; p^n(x)=p^{n+1}(x)$$ which we know exists for some $$n\in \mathbb(N)$$
   - As we know from above the root of an elememnt of $$A$$ is an element of $$A$$
   - and the root of an elememnt of $$R$$ is $$I_R$$

 - $$parts:\:A \cup R \to (A \cup R)_0^n$$: for $$n\in\mathbb{N}$$ mapping from a path, to a finite sequence of path from the path to the root
   - $$parts(x)$$ is given by:
      - \$$a_0 = b(x)$$
      - $$a_{n+1} = p(a_n)$$ if $$p(a_{n+1}) \neq a_{n-1}$$ otherwise not defined.
   - if $$x \in A$$ then the final element is a root of $$A$$, and all others in $$R$$
   - if $$x \in R$$ then the final element is the root of $$R$$ ($$I_R$$), and all elements are in $$R$$
   - $$\sum_{i==n}^{i=0} a_i = x$$ for $$parts(x) - (a_i)^n_0$$
      - The series of of $$part(x)$$ over the $$\cdot$$ operation is equal to $$x$$


 - $$relative\_to:\; (A \cup R)\times(A \cup R) \to R$$ which finds the relative path from one path to another
   - for $$relative\_to(x,y) = z$$  we say "the path of $$x$$, relative to $$y$$ is $$z$$"
   - it is defined only if $$root(y)=root(y)$$
   - $$relative\_to(x,y)$$ is give by:
      - defining $$parts(x) = (x_0, ... x_n)$$
      - defining $$parts(x) = (y_0, ... y_m)$$  
      - and we know $$x_n = y_m$$ which are the common root
      - we define $$t \in \mathbb(N)$$ as the largest value, such that $$\forall s \in \mathbb{N},\; s \le t \Rightarrow \; y_{m-s}=x_{n-s}$$
      - $$relative\_to(x,y) = \sum_{i==t}^{i=0} x_i$$, the subseries of parts over $$\cdot$$
   - notice that $$relative\_to(x,x) = I_R$$
 

### Resolving a Path to the object 
Finally we have an the operation that turns a absolute path ($$x\in A$$) into a entity, or a set of entities.
These operations are less clear, as at this level objects must be considered -- the data store (the indexed set) must be accessed to resolve. And issues like synlinks, hardlinks etc start to matter (To use examples POSIX filepaths).


 - Call this operation $$e$$ -- to evaluate the path
   - \$$e:\; A \to \subseteq \mathcal{P}(D)$$
   - for a $$D$$ the set of indexed objects (filesystem, document etc)
 - For $$x_1, x_2 \in A$$,  $$x_1=x_2 \Rightarrow eval(x_1) == eval(x_2)$$
      that is to say $$eval$$ is a function.
 - Depending on implementation, this may be 1 enitity, or many
   -  One might call Path schema with paths which always eval to one or zero entities MonoPath Schemas
        - eg URL, POSIX / NT File System paths
<!--   - In these case, one might intead define $$eval^\ast (A^\ast) \to D$$ where $A^\ast$ is the restriction of $A$ to paths that target objects that exists. It could well be said that this is meaningless sice $$eval^\ast$$ must be defined interm if $$eval$$, however this is close to the behavour of many programatic operations (like file-read), in that that it is a domain error, to use a path that does not target a legel object. -->
   -  one might call Path schema with paths that can eval to any nymber of entities MultiPaths Schemas
        - eg XPATH or Glob
 - On the cardinality of $$e(x)$$
   - for $$\abs{e(x)}$$ being the number of entities given by $$e(x)$$ -- the cardinality of the set
   - \$$\abs{e(p(x))} \le \abs{e(x)}$$ 
   - \$$\abs{e(x)} > 0  \Rightarrow \abs{e(p(x))} > 0$$
      - or its (perhaps more interesting) contra-positive: $$\abs{e(p(x))}=0 \Rightarrow \abs{e(x)}=0$$



