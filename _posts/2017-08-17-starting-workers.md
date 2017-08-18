---
title: Using julia -L startupfile.jl, rather than machinefiles for starting workers.
layout: default
tags:
   - julia
---



If one wants to have full control over the worker process to method to use is `addprocs` and the `-L startupfile.jl` commandline arguement when you start julia
See the documentation for [`addprocs`](https://docs.julialang.org/en/stable/stdlib/parallel/#Base.Distributed.addprocs).

The simplest way to add processes to the julia worker is to invoke it with `julia -p 4`.
The `-p 4` argument says start 4 worker processes, on the local machine.
For more control, one uses `julia --machinefile ~/machines`
Where `~/machines` is a file listing the hosts.
The machinefile is often just a list of hostnames/IP-addresses,
but sometimes is more detailed.
Julia will connect to each host and start a number of workers on each equal to the number of cores.

Even the most detailed machinefile doesn't give full control,
for example you can not specify the topology, or the location of the julia exectuable.

For full control, one shoud invoke `addprocs` directly,
and to do so, one should use `julia -L startupfile.jl`

<!--more-->  
 

Inkoking julia with `julia -L startupfile.jl ...`
causes julia to exectute `startupfile.jl` before all other things.
It can be invoked to start the REPL, or with a normal script afterwoods.
It is thus a good place to do `addprocs` rather than doing it at the top of the script being run,
since this allows the main script to be concerned only with the task.
 

On to a proper example,
let us assume one has 4 servers.
 - `host1` with 24 available cores
 - `host2` with 12 available cores
 - `host3` with 8 available cores


Doing this with machinefile would just be having  file:

```
host1
host2
host3
```

Assuming the number of workers desired is equal to the number of cores;
and you don't need anything fancy then using `julia -m ~/machinefile` is fine.
If you are working on a supercomputer or a cluster you likely have a method to generate a machinefile -- it is the same as is used by MPI etc.


However, let us also say that you want to use the `:master_slave` topology,
so all workers are only allowed to talk to the master process,
not to each other.
This is common in many clusters.

We can start a number of local workers, using `addproc(4)`.

```julia
for host in ["host1", "host2", "host3"]
	addproc(host; topology=:master_slave)
end
```

There is also an overload for this which takes a vector of hostnames.
So this can be done as:

```julia
addproc(["host1", "host2", "host3"]; topology=:master_slave)
```

This method will use the default number of workers, i.e. equal to the core count.
It also takes an overload allowing one to specify the number of worker on each process:

```julia
addproc([("host1", 24), ("host2", 12), ("host3", 8)]; topology=:master_slave)
```

Further to this, instread of a hostname,
one can  provide a line from a machine file.

Thus:
one can read every line from a machinefile by: `collect(eachline("~/machinefile"))`


```julia
addproc(collect(eachline("~/machinefile")); topology=:master_slave)
```

This is useful, if your system is providing you with a machine file.


The short of all this is,
using `julia -L startup.jl` is the most powerful,
and generally best way to do anything when it comes to setting up your distributed julia worker processes.
