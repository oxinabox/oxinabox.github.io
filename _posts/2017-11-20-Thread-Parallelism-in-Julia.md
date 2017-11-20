---
layout: default
title: "Thread Parallelism in Julia"
tags:
    - julia
    - jupyter-notebook
---
Julia has 3 kinds of parallelism.
The well known, safe, slowish and easyish, *distributed parallelism*, via `pmap`, `@spawn` and `@remotecall`.
The wellish known, very safe, very easy, not-actually-parallelism, *asynchronous parallelism* via `@async`.
And the more obscure, less documented, experimental, really unsafe, *shared memory parallelism* via `@threads`.
It is the last we are going to talk about today.

I'm not sure if I can actually teach someone how to write threaded code.
Let alone efficient threaded code.
But this is me giving it a shot.
The example here is going to be fairly complex.
For a much simpler example of use,
on a problem that is more easily parallelizable,
see my recent [stackoverflow post on parallelizing sorting](https://stackoverflow.com/a/47235391/179081).

(Spoilers: in the end I don't manage to extract any serious performance gains from parallelizing this prime search. Unlike parallelizing that sorting. Paralising sorting worked out great)

<!--more-->

In a [previous post](http://white.ucc.asn.au/2017/11/18/Lazy-Sequences-in-Julia.html#primes),
I used prime generation as an example to motivate the use of coroutines as generators.
Now coroutines are neither parallelism, nor fast.
Lets see how fast we can go if we want to crank it up using  `Base.Threading`.
(answer: not as much as you might hope).

I feel that julia threading is a bit nerfed.
In that all threading must take place in a for-loop, where work is distributed equally to all threads.
And the loop end blocks til all threads are done.
You can't just fire off one thread to do a thing and then let it go.
I spent some time a while ago trying to workout how to do that,
and in short I found that end of thread block is hard to get around.
`@async` on its own can't break out of it.
Though one could rewrite ones whole program to never actually exit that loop.
But then one ends up building own own threading system.
And I have a thesis to finish.

## Primes
This is the same paragraph from that earlier post.
**I'll let you know now, this is not an optimal prime number finding algorithm, by any means.**
We're just using it for demonstration. It has a good kind of complexity for talking about shared memory parallelism.


If a number is prime, then no prime (except the number itself), will divide it.
Since if it has a divisor that is non-prime, then that divisor itself, will have a prime divisor that will divide the whole.
So we only need to check primes as candidate divisors.
Further: one does not need to check divisibility by all prior primes in order to check if a number $s$ is prime.
One only needs to check divisibility by the primes less than or equal to $\sqrt{x}$, since if $x=a \times b$, for some $a>\sqrt{x}$ that would imply that $b<\sqrt{x}$, and so its composite nature would have been found when $b$ was checked as a divisor.

Here is the channel code for before:

**Input:**

{% highlight julia %}
using Base.Test
using Primes
{% endhighlight %}

**Input:**

{% highlight julia %}
function primes_ch(T=BigInt)
    known_primes = T[2]
    Channel(csize=256, ctype=T) do c
        x = big"3"
        put!(c, 2) # Output the first prime, as we already put int in the list of known primes
        while true
            for p in known_primes
                if p > sqrt(x)
                    # Must be prime as we have not found any divisor
                    push!(known_primes, x)
                    put!(c, x)
                    break
                end
                if x % p == 0 # p divides
                    # not prime
                    break
                end
            end
            x+=1            
        end
    end
end
{% endhighlight %}

**Output:**




    primes_ch (generic function with 2 methods)



**Input:**

{% highlight julia %}
@time collect(Iterators.take(primes_ch(UInt), 10^4));
@time collect(Iterators.take(primes_ch(BigInt), 10^4));
{% endhighlight %}

**Output:**

{% highlight plaintext %}
  1.076319 seconds (6.91 M allocations: 258.664 MiB, 20.54% gc time)
  1.139354 seconds (6.10 M allocations: 240.307 MiB, 17.69% gc time)

{% endhighlight %}

### Primes Array

So the first and obvious thing to do is to switch to doing this eagerly with an array.

**Input:**

{% highlight julia %}
function primes_array(n,T=UInt)
    known_primes = T[2]
    sizehint!(known_primes, n)
    
    x=T(3)
    while true
        for p in known_primes
            if p > sqrt(x)
                # Must be prime as we have not found any divisor
                push!(known_primes, x)
                break
            end
            if x % p == 0 # p divides
                # not prime
                break
            end
        end
        x+=1
        length(known_primes) == n && break
    end
    return known_primes
end
{% endhighlight %}

**Output:**




    primes_array (generic function with 2 methods)



**Input:**

{% highlight julia %}
@time primes_array(10^4, UInt);
@time primes_array(10^4, BigInt);
{% endhighlight %}

**Output:**

{% highlight plaintext %}
  0.188296 seconds (1.70 M allocations: 26.084 MiB, 11.46% gc time)
  1.356425 seconds (5.89 M allocations: 231.466 MiB, 15.92% gc time)

{% endhighlight %}

**Input:**

{% highlight julia %}
@time primes_array(10^5, Int);
{% endhighlight %}

**Output:**

{% highlight plaintext %}
  3.627753 seconds (26.43 M allocations: 404.349 MiB, 0.73% gc time)

{% endhighlight %}

This gives an improvement, but not as much as we might really hope for.
(as you will see below getting more out of it is harder).

### Gutting `@threads` for
the `@threads` macro eats for-loops and breaks up their ranges equally, one block per thread.
That isn't very practical is your plan does not just a processing of some data that doesn't depend strongly on the order of processing.


We don't plan on sequentially processing the data, since breaking all numbers into equal blocks, would result the final thread not being able to do anything until almost all the other threads were done.
For this algorithm we need to know all the prime numbers less than $\sqrt{x}$ before we can check if $x$ is prime.
So we have a sequential component.

So we gut the `@threads` macro, taking the core functionality,
and we will manage giving work to the threads ourselves.

**Input:**

{% highlight julia %}
using Base.Threads
@show nthreads()

"""
    everythread(fun)
Run `fun` on everythread.
Returns when every instance of `fun` completes
"""
everythread(fun) = ccall(:jl_threading_run, Ref{Void}, (Any,), fun)
{% endhighlight %}

**Output:**

{% highlight plaintext %}
nthreads() = 10

{% endhighlight %}




    everythread



Just to check it is working:

**Input:**

{% highlight julia %}
called = fill(false, nthreads())
everythread() do 
    called[threadid()] = true
end
called |> showcompact
{% endhighlight %}

**Output:**

{% highlight plaintext %}
Bool[true, true, true, true, true, true, true, true, true, true]
{% endhighlight %}

#### push_sorted!
Before we can get into actually working on the parallelism, we need another part.

Pushing to the end of our list of `known_primes` is no longer going to guarantee order.
One thing we will need is the ability to `push!` that does maintain order.
Because otherwise we could endup thinking we have checked enough factors but actually we skipped over one.
(I made that mistake in an earlier version of this code).

We could use a priority queue for this, but since known primes will always be almost sorted,
I think it is going to be faster just to insert the elements into a normal vector.
Less pointer dereferencing than using a heap.

**Input:**

{% highlight julia %}
"""
inserts `xs` at the last position such that all elements prior to it are smaller than it.
And all after (if any) are larger.
Assumes `xs` is sorted (increasing),
"""
function push_sorted!(xs, y)
	for ii in endof(xs):-1:1
		@inbounds prev = xs[ii]
		if prev < y
			insert!(xs, ii+1, y) # ii+1 is the index in the resulting array for y
			return xs
		end
	end
	# If got to here then y must be the smallest element, so put at start
	unshift!(xs, y)
end

using Base.Test
@testset "push_sorted!" begin
    xs = [1,2,4]
    @test push_sorted!(xs, 5) == [1,2,4,5]
    @test push_sorted!(xs, 3) == [1,2,3,4,5]
    @test push_sorted!(xs, 0) == [0,1,2,3,4,5]
end;
{% endhighlight %}

**Output:**

{% highlight plaintext %}
Test Summary: | Pass  Total
push_sorted!  |    3      3

{% endhighlight %}

# primes threaded

Ok so here we go with the main content of this piece.

Here is our plan.

 - We will have a shared list of all `known_primes` recording what we know.
 - Each thread will grab a number and check if it is prime, if it is prime it will add it to that list.
 - To check if it is prime, it needs to check for if there are no primes that divide it.
 - This means that if there is a prime divisor that is not yet ready it must wait until it is.


So what can go wrong?
The most important part of getting share memory parallism correct is making sure **at no point is the same piece of memory being both written and read** (or written and written).
There is no promise that any operation is actually atomic, except **atomic** operations, and the setting of **locks**.
Which brings me to our two tools for dealing with ensuring that memory is not dual operated on.

Atomic operators are a small set of operations available on primitive types.
They run on atomic types.
They might not perform quiet the operation you expect (so [read the docs](https://docs.julialang.org/en/release-0.6/stdlib/parallel/#Base.Threads.Atomic)).
For example `atomic_add!(a::Atomic{T}, b::T)`  updates the value of `a`, but returns its old value, as type `T`.
Julia's atomics come out of LLVM, more or less directly.

Then there are locks.
These are what you use if you want to make a block of code (which might modify non-primitively typed memory) not run at the same time as some other block of code.
Julia has two kinds of locks `TatasLock`/`SpinLock`, and `Mutex`.
We're going to use the first kind, they are based on **atomics**.
The second kind (the `Mutex`) is based on lib_uv's OS agnostic wrapper of they OS's locking system.

So what do we need to restrict:

 - `next_check`: the integer that keeps track what is the next. If we let multiple threads read it at the same time then they will initially keep checking the same numbers as each other. Once they get out of sync bad things will happen. Since it is a primitive type (unless a BigInt or similar is passed as the type) we can use an atomic.
 - `known_primes`: the list of primes we know about. Here are the operations we need to prevent against:
    - Reading an element while it is being written (obvious reasons)
    - Reading the length of the vector while something is being inserted (may return corrupt overly high value, leading to incorrect state flow in the program, and/or a segfault)
    - Reading **any** element while an element is being inserted. This one caught me out, badly, a lot. Even if the element you are reading isn't being touched, it can still fail. The reason for this is that the `Vector` basically reserves (and uses) the right to move itself in memory whenever an element is added, even if you `sizehint!` it. If this occurs in the middle of a `getindex` then the value you think you are reading might not be there any more.
    
    
The other thing we have going on is that we want to sleep our current thread if we are blocked by waiting for a missing prime.
This is done using `Condition`, `wait` and `notify`  ([docs](https://docs.julialang.org/en/stable/manual/control-flow/#Tasks-and-events-1)).
The advantage of sleeping the thread while it is waiting is that if oversubscribed (or you are doing other things on the computer), any threads currently waiting for a turn on the CPU can get it. I'm not oversubscribing here so it doesn't really matter. If anything it is slowing it down.
Still it is good practice, and makes you a polite multi-threading citizen.

**Input:**

{% highlight julia %}
function primes_threaded(n,T=UInt128)
    known_primes_lock = SpinLock()
    prime_added = Condition()
    known_primes = Vector{T}()
    sizehint!(known_primes, n + nthreads()) #Allocate extra memory inc
    push!(known_primes, 2)
    
    function safe_length_known_primes()
        lock(known_primes_lock) do
            length(known_primes)
        end
    end
    
    function ith_prime(ii) # try and read the ith prime, if it is available. If not theen wait til it is
        while(safe_length_known_primes()<ii)
            wait(prime_added)
        end
        local ret
        lock(known_primes_lock) do
            @inbounds ret = known_primes[ii]
            # we need this lock incase it is being reshuffled
        end
        ret
    end
    
    function add_prime!(p) # Add a prime to our list and let anyone why was waiting for it know 
        lock(known_primes_lock) do
            push_sorted!(known_primes, p)
        end
        notify(prime_added, all=true)
    end

    
    next_check = Atomic{T}(3) # This is the (potentially prime) number the next thread that asked for something to check will et
    everythread() do
        while(true)
            x=atomic_add!(next_check, T(1)) #atomic_add! returns the *old* value befoe the addition
            for ii in 1:x #Not going to get up to this but it will be fine (except at x=2, got to watch that, goot thing we already have 2 covered)
                p = ith_prime(ii) 
                if p > sqrt(x)
                    # Must be prime as we have not found any divisor
                    add_prime!(x)
                    break
                end
                if x % p == 0 # p divides
                    # not prime
                    break
                end
            end

            if safe_length_known_primes() >= n
                return
            end
        end
    end
    return known_primes
end
{% endhighlight %}

**Output:**




    primes_threaded (generic function with 2 methods)



**Input:**

{% highlight julia %}
ps = primes_threaded(10^5, Int)
fails = ps[.!isprime.(ps)]
{% endhighlight %}

**Output:**




    0-element Array{Int64,1}



**Input:**

{% highlight julia %}
@time primes_threaded(10^4, Int);
@time primes_array(10^4, Int);
{% endhighlight %}

**Output:**

{% highlight plaintext %}
  0.781142 seconds (3.67 M allocations: 68.560 MiB)
  0.475077 seconds (902.99 k allocations: 13.904 MiB, 49.03% gc time)

{% endhighlight %}

#### Wait it is slower?
That is right,
this multi-threaded code is much slower that the array code.
Getting performance out of multi-threading is hard.

I can't teach it.
But I can show you want I am going to work it out next.
My theory is that there is too much lock contention.

## Reducing Lock Contention

Working in blocks reduces contention, it also results in more cache-friendly code.
Instead of each thread asking for one number to check then checking it,
then asking for another,
each thread asks for a bunch to check at a time.
The obvious contention reduction is with the atomic `next_check`.
The less obvious is in the lock for `known_primes` which is checked ever time one wants to know how long it is to test if it is time to exit the loop.

In the code that follows, while each thread asks for a block of numbers to check at a time, it reports found primes individually. I looked at having each thread collect them up localizing in a block and then inserting them into the main-list all at once. But I found that actually slowed things down. It mean allocating a lot more memory, and (I guess) the longer consecutive time in which `known_primes` was locked for the big inserts was problematic.
Delaying checks for longer.

The really big cause of contention, I feel is the time to read `known_primes`.
Especially, the earlier elements.
The smaller the prime the more likely it is to be a factor.
So we would like to at least be able to check these early primes without worrying about getting locks.
To do that we need to maintain a separate list of them.

I initially, just wanted to have an atomic value keeping track of up to how far in `known_primes`, was safe to read, without having to worry about the elements changing.
Such that everything was in one array; and we knew which were safe to read.
But we can't do that, because inserting elements can cause the array to reallocate, so requires it to be locked.
So we just use a second array.

**Input:**

{% highlight julia %}
function primes_avoid(n,T=UInt128, blocksize=256)
    known_primes_lock = SpinLock()
    prime_added = Condition()
    
    pre_known_primes = primes_array(blocksize, T) # most common factors, stored so we don't need to lock to check them
    #Unfortunately we need to store a separate list, and can't just have a nonmutating part of the mainlist, as even with sizehinting it sometimes deallocates during an insert
    
    known_primes = Vector{T}()
    # Need to initialize it with enough primes that no block is ever waiting for a prime it itself produces   
    sizehint!(known_primes, n + nthreads()*ceil(Int, log(blocksize))) #Allocate extra memory inc
    
    function safe_length_known_primes()
        lock(known_primes_lock) do
            length(known_primes)
        end
    end
    
    function ith_prime(ii) # try and read the ith prime, if it is available. If not theen wait til it is
        local ret
        if ii < length(pre_known_primes)
            @inbounds ret = pre_known_primes[ii] 
        else
            ii-=length(pre_known_primes) # reindex for main list
        
            while(safe_length_known_primes()<ii)
                wait(prime_added)
            end

            lock(known_primes_lock) do
                @inbounds ret = known_primes[ii] 
            end
        end
        ret
    end
       
    function add_prime!(p) # Add a prime to our list and let anyone why was waiting for it know 
        lock(known_primes_lock) do
            push_sorted!(known_primes, p)
        end
        notify(prime_added, all=true)
    end
    
    next_check = Atomic{T}(blocksize + 1) #already checked the first block during initialisation
    everythread() do
    #(f->f())() do
        while(true)
            x_start=atomic_add!(next_check, T(blocksize)) #atomic_add! returns the *old* value befoe the addition
            x_end = x_start + blocksize
            for x in x_start:x_end
            
                for ii in 1:x #Not going to get up to this but it will be fine (except at x=2, got to watch that, goot thing we already have 2 covered)
                    p = ith_prime(ii) 
                    if p > sqrt(x)
                        # Must be prime as we have not found any divisor
                        add_prime!(x)
                        break
                    end
                    if x % p == 0 # p divides
                        # not prime
                        break
                    end
                end
            end
            safe_length_known_primes() + length(pre_known_primes) > n && return
        end
    end
    
    return append!(pre_known_primes, known_primes)
end
{% endhighlight %}

**Output:**




    primes_avoid (generic function with 3 methods)



**Input:**

{% highlight julia %}
@time primes_avoid(10^4, Int, 256);
@time primes_array(10^4, Int);
{% endhighlight %}

**Output:**

{% highlight plaintext %}
  0.235902 seconds (889.55 k allocations: 18.294 MiB)
  0.162847 seconds (902.99 k allocations: 13.904 MiB)

{% endhighlight %}

**Input:**

{% highlight julia %}
gc()
@time primes_avoid(10^5, Int, 256);
@time primes_array(10^5, Int);
{% endhighlight %}

**Output:**

{% highlight plaintext %}
  6.886030 seconds (20.65 M allocations: 436.509 MiB)
  4.135483 seconds (26.43 M allocations: 404.349 MiB)

{% endhighlight %}

So with that we've manage to scrape in a bit closers, but we are still losing to the single threaded array.

### Flaw in this algorithm when running in parallel
There is actually a flaw in this algorithm, I think.
Potentially, if your threads are far enough out of sync,
one could be waiting for a prime potential factor,
and the prime factor that arrives next, is not actually the next prime;
and further more that prime arriving early is larger than $\sqrt{x}$, so terminates the search;
incorrectly reporting $x$ as prime.
Which if the next prime to arrive was smaller than $\sqrt{x}$ and was a prime factor of $x$, that would make $x$ not a prime.

One solution would be to keep trace of which indices are actually stable.
We know an index is stable if it every thread is now working on checking a number that is greater than the prime at that index.

Pretty sure it is super unlikely and never happens,
but a fix for it gives me an idea for how to go faster

## Working in blocks seriously

Before I said we were working in blocks but we were still pushing everything into a single array at the end.
We could actually work in Vector of Vectors,
it makes indexing harder but lets us be fine grained with our locks.

So what we are going to do is at the start of each block,
we are going to reserve a point in out Vector of Vectors known primes,
as well as what numbers we are going to check.

We need to allocate all the block locations at the start,
because increasing the size of an array is not threadsafe.
A big complication is we don't know how many blocks we are going to need.
It took me a long time to workout the solution to this.
What we do is when we run out of allocated memory we let the block of code that is running on all threads terminate,
then we allocate more memory and restart it.

This code is pretty complex.
As you can see from all the assert statements it took me a fair bit of debugging to get it right.
Its still not much (if at all) better than serial.
But I think it well illustrates how you have to turn problems around to eak out speed when trying to parallelize them.

Note in particular how `reserved_blocks` is a vector of atomics indexed by `threadid()` to keep track of what memory is being held by what thread.

**Input:**

{% highlight julia %}
function primes_blockmore(n,T=UInt128, blocksize=256)
    reserved_blocks = [Atomic{Int}(typemax(T)) for _ in 1:nthreads()]
    reserved_conds = [Condition() for _ in 1:nthreads()]
    
    function inc_prime_pointer(block, ind) # try and read the ith prime, if it is available. If not theen wait til it is       
        #@assert block<minimum(getindex.(reserved_blocks))
        #@assert(block<=safe_length_known_primes[], "1 rbs= $(getindex.(reserved_blocks)), kp=$(safe_length_known_primes[]), block=$(block)")           
        #@assert(isassigned(known_primes, block), "block not assigned $(threadid()) $(block)")
        if length(known_primes[block])>ind
            (block, ind+1)
        else
            #time to move to the next block
            block += 1
            for (owner, rb) in enumerate(reserved_blocks)
                while true
                    # Check to make sure the block we want to read isn't still reserved.
                    if block == rb[]
                        # Technically I think I actually need to synconize here,
                        # against the lock being released in between me looking at it 
                        # and me wanting to wait for it's condition.
                        @inbounds wait(reserved_conds[owner]) #wait til that block is ready
                        break
                    end
                    length((known_primes[block]))>0 & break # skip empty blocks
                end

            end
            #@assert length(known_primes[block])>0
            #@assert block<minimum(getindex.(reserved_blocks))
            #@assert(block<=safe_length_known_primes[], "2 rbs= $(getindex.(reserved_blocks)), kp=$(safe_length_known_primes[]), block=$(block)")
            (block, 1)
        end
    end
      
    reserving_block_lock = SpinLock()
    next_check = blocksize # Not an atomic as we are already protecting it with a lock
    function get_next_block()
        reservation = Vector{T}()
        lock(reserving_block_lock) do
            
            cur_len = true_length_known_primes[]
            out_of_allocation = cur_len == max_true_length_known_primes
            @assert cur_len < max_true_length_known_primes
            if out_of_allocation
                (true, (reservation, -1,-1)) # could be using a nullable here, but I don't want the pointer
            else
                atomic_add!(true_length_known_primes, 1)
                cur_len += 1
                reserved_blocks[threadid()][] = cur_len
                @inbounds known_primes[cur_len] = reservation
                cur_check = next_check            
                next_check+=blocksize
                
                (false, (reservation, cur_check, cur_check + blocksize))
            end
        end
    end
    
    ## Setup initial known_primes
    known_primes = Vector{Vector{T}}(1)
    max_true_length_known_primes = 1;
    @inbounds known_primes[1] = primes_array(blocksize, T)
    
    @inbounds total_known = Atomic{Int}(length(known_primes[1]))
    true_length_known_primes = Atomic{Int}(1) #The number of blocks that are started, exactly
    safe_length_known_primes = Atomic{Int}(1) #The number of blocks that are done, a lower bound
    
    
    blocksize÷=0.5
    while(total_known[] < n) # This outerloop is to add more memory when we run out of blocks, so everything must sync up
        blocksize*=2 # double the size each round as primes are getting rarer.
        @show total_known[], next_check[]
        flush(STDOUT)
        max_true_length_known_primes += n;
        # The upper bound on how many blocks we will allow
        # unfortunately this is more than 1 block per prime
        # without solving for the inverse Prime number theorem it is hard to bound
        # have to preallocate it, AFAICT `push!` is never threadsafe.
        append!(known_primes, Vector{Vector{T}}(max_true_length_known_primes))
        # We are now in a position to reallocated it
        
        everythread() do
        #(f->f())() do #this line is useful instead of everythread for debugging
            while(true)
                (done, (local_primes, x_start, x_end)) = get_next_block()
                done && return # quit now, we are out of allocated memory
                for x in x_start:x_end
                    pp_block, pp_ind = (1, 1)
                    while(true)

                        # if we have an index for it we know it is safe to read
                        @inbounds p = known_primes[pp_block][pp_ind]
                        if p > sqrt(x)
                            # Must be prime as we have not found any divisor
                            push!(local_primes, x)
                            break
                        end
                        if x % p == 0 # p divides
                            # not prime
                            break
                        end
                        pp_block, pp_ind = inc_prime_pointer(pp_block, pp_ind)
                    end
                end

                #End of block stuff.
                @inbounds notify(reserved_conds[threadid()], all=true)
                atomic_add!(safe_length_known_primes, 1)
                @assert length(local_primes) > 0
                atomic_add!(total_known, length(local_primes))
                total_known[] > n && return
            end
        end
    end
    
    known_primes=known_primes[1:true_length_known_primes[]]
    all_primes = T[]
    sizehint!(all_primes, n)
    reduce(append!, T[], known_primes)    
end
{% endhighlight %}

**Output:**




    primes_blockmore (generic function with 3 methods)



**Input:**

{% highlight julia %}
gc()
@time primes_blockmore(10^4, Int, 256);
{% endhighlight %}

**Output:**

{% highlight plaintext %}
(total_known[], next_check[]) = (256, 256)
  0.169644 seconds (847.93 k allocations: 17.723 MiB)

{% endhighlight %}

**Input:**

{% highlight julia %}
gc()
pr = @time primes_blockmore(10^5, Int, 256);
{% endhighlight %}

**Output:**

{% highlight plaintext %}
(total_known[], next_check[]) = (256, 256)
  4.106018 seconds (16.94 M allocations: 355.002 MiB)

{% endhighlight %}

**Input:**

{% highlight julia %}
gc()
@time primes_blockmore(5*10^5, Int, 256);
{% endhighlight %}

**Output:**

{% highlight plaintext %}
(total_known[], next_check[]) = (256, 256)
 64.109311 seconds (226.03 M allocations: 4.581 GiB, 7.13% gc time)

{% endhighlight %}

**Input:**

{% highlight julia %}
gc()
@time primes_array(5*10^5, Int);
{% endhighlight %}

**Output:**

{% highlight plaintext %}
 39.164720 seconds (348.88 M allocations: 5.203 GiB, 1.81% gc time)

{% endhighlight %}

## Conclusion
So with all that, 
We are still losing to the single threaded code.
Maybe if we were using more threads.
Or if the code was smarter,
we could pull ahead and go faster.
But today, I am willing to admit defeat.
It is really hard to make this kinda code actually speed-up.

If you can do better, I'ld be keen to know.
You can get the notebook that is behind this post from
[github](https://github.com/oxinabox/oxinabox.github.io/blob/master/notebook_posts/Thread%20Parallelism%20in%20Julia.ipynb),
you could even fork it and make a PR and I'll regenerate this blog post (:-D).

One way to make it much much faster is to use a different algorithm.
I'm sure there actually exist well documented parallel prime finders.
