---
layout: default
title: "Asynchronous and Distributed File Loading"
tags:
    - julia
    - jupyter-notebook
---
Today we are going to look at loading large datasets in a asynchronous and distributed fashion.
In a lot of circumstances it is best to work with such datasets in an entirely distributed fashion,
but for this demonstration we will be assuming that that is not possible,
because you need to Channel it into some serial process.
But it doesn't have to be the case.
Anyway, we use this to further introduce `Channel`s and `RemoteChannel`s.
I have [blogged about `Channel`s before]({{site.url}}/2017/11/18/Lazy-Sequences-in-Julia.html),
you make wish to skim that first.
That article focused on single producer single consumer.
This post will focus on multiple producers, single consumer.
(though you'll probably be able to workout multiple consumers from there, it is pretty semetrical).
<!--more-->

This is an expanded explination of some code I originally posted this on the [Julia Discourse](https://discourse.julialang.org/t/example-of-async-distributed-loading-into-a-single-shared-channel/11815).
I find the documentation on channels took me a bit to get my head around for this,
so I hope this extra example helps you to understand

We are wanting to process a large dataset.
In this case the Open Research Corpus, from Semantic Scholar.
Below is a [DataDep](https://github.com/oxinabox/DataDeps.jl) that will download that.
It actually downloads really fast, because DataDeps.jl uses asyncs (roughly the same ones we'll use later),
to trigger the downloads of each file in parallel.
I was getting around 70MB/s down which is pretty great.
Though those async's were triggering the downloads in separate processes, so to an extent it is more like distributed programming than asynchronous -- but without the asyncs julia would wait for each download to be complete before proceeding.
Julia's distributed programming system is built on top of its asynchronous programming system in any case.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
addprocs(8) # Loading up processors first so they get all the modules
@everywhere using WordTokenizers
@everywhere using CodecZlib
@everywhere using JSON
@everywhere using Glob
@everywhere using Base.Iterators
@everywhere const BUFFER_SIZE = 2^10
@everywhere using DataDeps


register(DataDep(
    "Open Research Corpus",
"""
Dataset License Agreement
This Dataset License Agreement (“License”) is a legal agreement between you and the Allen Institute for Artificial Intelligence (“AI” or “we”) for Data made available to the individual or entity exercising the licensed rights under this License (“You” or “Your”). “Data” includes all text, data, information, source code, and any related materials, documentation, files, media, and any updates or revisions We may provide.
By exercising any of the licensed rights below, You accept and agree to be bound by the terms and conditions of this License. To the extent this License may be interpreted as a contract, You are granted the licensed rights in consideration of Your acceptance of these terms and conditions, and We grant You such rights in consideration of benefits that We receive from making the Data available under these terms and conditions. If You do not agree to the License, You may not use the Data. Subject to the conditions of this License, AI grants You a worldwide, royalty-free, non-sublicensable, non-exclusive, irrevocable (except as described herein) license under AI’s copyright rights, solely for non-commercial research and non-commercial educational purposes, to copy, reproduce, prepare derivate works of, perform, perform publicly, display, adapt, modify, distribute, and otherwise use this Data.
You grant to AI, without any restrictions or limitations, a non-exclusive, worldwide, perpetual, irrevocable, royalty-free, assignable and sub-licensable copyright license to copy, reproduce, prepare derivate works of, perform, perform publicly, display, adapt, modify, distribute, and otherwise use your modifications to and/or derivative works of the Data, for any purpose.
Any and all commercial use of this Data is strictly prohibited. Prohibited commercial use includes, but is not limited to, selling, leasing, or licensing the Data for monetary or other commercial gain, using the Data in connection with business functions or operations, or embedding or installing the Data into products for your own commercial gain or for the commercial gain of third parties. If you are uncertain as to whether your contemplated use of the Data is permissible, do not use this Data and instead contact AI for further information.
Do not remove any copyright or other notices from the Data.
Any distribution of the Data or any derivative works of the Data must be under the same terms and conditions as in this License, and the disclaimer of warranties in Section 7 of this License must be included in any distribution of the Data to a third party.
If you adapt, modify, or create derivative versions of the Data, indicate that You have modified the original Data and provide the date(s) of such modifications.
You agree and acknowledge that any feedback, suggestions, ideas, comments, improvements or other input (“Feedback”) about the Data provided by You to AI is voluntarily given, and AI shall be free to use the Feedback as it sees fit without obligation or restriction of any kind. THE DATA COMES “AS IS”, WITH NO WARRANTY. AI EXPRESSLY DISCLAIMS ANY EXPRESS, IMPLIED OR STATUTORY WARRANTY, INCLUDING WITHOUT LIMITATION, THE WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, ANY WARRANTY AGAINST INTERFERENCE WITH YOUR ENJOYMENT OF THE SOFTWARE, AND ANY WARRANTY OF TITLE OR NON-INFRINGEMENT. THE DATA IS NOT WARRANTIED TO FULFILL ANY OF YOUR PARTICULAR PURPOSES OR NEEDS.
NEITHER AI NOR ANY CONTRIBUTOR TO THE DATA SHALL BE LIABLE FOR ANY DAMAGES RELATED TO THE DATA OR THIS LICENSE, INCLUDING DIRECT, INDIRECT, OTHER, PUNITIVE, SPECIAL, CONSEQUENTIAL OR INCIDENTAL DAMAGES, TO THE MAXIMUM EXTENT THE LAW PERMITS, REGARDLESS OF THE LEGAL THEORY SUCH CLAIM OR DAMAGES IS BASED ON, EVEN IF AI HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES. AI’S TOTAL AGGREGATE LIABILITY, UNDER ANY THEORY OF LIABILITY, SHALL NOT EXCEED US\$10. YOU MUST PASS ON THIS LIMITATION OF LIABILITY ON WHENEVER YOU DISTRIBUTE THE DATA OR DERIVATIVE WORKS THEREOF.
We have no duty of reasonable care or lack of negligence, and we are not obligated to (and will not) provide technical support for the Data.
If you breach this License or if you sue anyone over any intellectual property regarding the Data, or another party’s use thereof, your license to the Data shall terminate automatically. You will immediately cease all use and distribution of the Data and destroy any copies or portions of the Data in your possession. Other terms of this License that should survive such termination of this License shall survive.
The Data may be subject to U.S. export jurisdiction at the time it is licensed to you, and it may be subject to additional export or import laws in other places. You agree to comply with all such laws and regulations that may apply to the Data.
All rights not expressly granted to You herein are reserved. This License does not convey an ownership right to You or any Third Party. The Data is licensed, not sold.
This License shall be construed and controlled by the laws of the State of Washington, USA, without regard to its conflicts of law doctrine. Venue for any action related to this License or the Data shall limited to the state and federal courts of the USA having jurisdiction over Seattle, WA, and You expressly consent to such venue and jurisdiction and expressly waive any challenge to such venue and jurisdiction. If any provision of this License shall be deemed unenforceable or contrary to law, the rest of this License shall remain in full effect and interpreted in an enforceable manner that most nearly captures the intent of the original language. The U.N. Convention on the International Sale of Goods is expressly excluded and does not apply to this License.
By downloading this Data you acknowledge that you have read and agreed all the terms in this License, and represent and warranty that You have authority to do so on behalf of any entity exercising the licensed rights under this License.
--------------------------------------------------------
This is a subset of the full Semantic Scholar corpus which represents papers crawled from the Web and subjected to a number of filters.
Website: http://labs.semanticscholar.org/corpus/
Year: 2018
Authors: Waleed Ammar and Dirk Groeneveld and Chandra Bhagavatula and Iz Beltagy and Miles Crawford and Doug Downey  and Jason Dunkelberger and Ahmed Elgohary and Sergey Feldman and Vu Ha and Rodney Kinney
  and Sebastian Kohlmeier and Kyle Lo and Tyler Murray and Hsu-Han Ooi and Matthew Peters and Joanna Power
   and Sam Skjonsberg and Lucy Lu Wang and Chris Wilhelm and Zheng Yuan and Madeleine van Zuylen and Oren Etzion
--------------------------------------------------------
It is requested that that any published research that makes use of this data cites the following paper:
Waleed Ammar et al. 2018. Construction of the Literature Graph in Semantic Scholar. NAACL.
https://www.semanticscholar.org/paper/09e3cf5704bcb16e6657f6ceed70e93373a54618
""",
    ["https://s3-us-west-2.amazonaws.com/ai2-s2-research-public/open-corpus/" .* split("""
    corpus-2018-05-03/s2-corpus-00.gz	corpus-2018-05-03/s2-corpus-01.gz
    corpus-2018-05-03/s2-corpus-02.gz	corpus-2018-05-03/s2-corpus-03.gz
    corpus-2018-05-03/s2-corpus-04.gz	corpus-2018-05-03/s2-corpus-05.gz
    corpus-2018-05-03/s2-corpus-06.gz	corpus-2018-05-03/s2-corpus-07.gz
    corpus-2018-05-03/s2-corpus-08.gz	corpus-2018-05-03/s2-corpus-09.gz
    corpus-2018-05-03/s2-corpus-10.gz	corpus-2018-05-03/s2-corpus-11.gz
    corpus-2018-05-03/s2-corpus-12.gz	corpus-2018-05-03/s2-corpus-13.gz
    corpus-2018-05-03/s2-corpus-14.gz	corpus-2018-05-03/s2-corpus-15.gz
    corpus-2018-05-03/s2-corpus-16.gz	corpus-2018-05-03/s2-corpus-17.gz
    corpus-2018-05-03/s2-corpus-18.gz	corpus-2018-05-03/s2-corpus-19.gz
    corpus-2018-05-03/s2-corpus-20.gz	corpus-2018-05-03/s2-corpus-21.gz
    corpus-2018-05-03/s2-corpus-22.gz	corpus-2018-05-03/s2-corpus-23.gz
    corpus-2018-05-03/s2-corpus-24.gz	corpus-2018-05-03/s2-corpus-25.gz
    corpus-2018-05-03/s2-corpus-26.gz	corpus-2018-05-03/s2-corpus-27.gz
    corpus-2018-05-03/s2-corpus-28.gz	corpus-2018-05-03/s2-corpus-29.gz
    corpus-2018-05-03/s2-corpus-30.gz	corpus-2018-05-03/s2-corpus-31.gz
    corpus-2018-05-03/s2-corpus-32.gz	corpus-2018-05-03/s2-corpus-33.gz
    corpus-2018-05-03/s2-corpus-34.gz	corpus-2018-05-03/s2-corpus-35.gz
    corpus-2018-05-03/s2-corpus-36.gz	corpus-2018-05-03/s2-corpus-37.gz
    corpus-2018-05-03/s2-corpus-38.gz	corpus-2018-05-03/s2-corpus-39.gz""")
    "https://s3-us-west-2.amazonaws.com/ai2-s2-research-public/open-corpus/license.txt"
    ];
));
{% endhighlight %}
</div>

So let's take a look at one of these files.
We are using [CodecZlib](https://github.com/bicycle1885/CodecZlib.jl) to decompress the gzip while reading the stream  from.
Decompressing gzip this way doesn't add much overhead,
thus when it isn't a gzipped tarball I don;t see much reason to extract it.
We'll just read off the first line.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
open(GzipDecompressorStream, datadep"Open Research Corpus/s2-corpus-39.gz") do stream
    for line in eachline(stream)
        println(line)
        break
    end
end
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
{"entities":["Alpha-glucosidase","Amino Acid Sequence","Amino Acids","Biopolymer Sequencing","DNA, Complementary","GLUCOSIDASE","Gene Amplification Technique","Homologous Gene","Maltose","Molecular Mass","Mucor","Open Reading Frames","Polymerase Chain Reaction","Polypeptides","Reverse Transcription","Starch"],"journalVolume":"119 3","journalPages":"500-5","pmid":"8830045v1","year":1996,"outCitations":[],"s2Url":"https://semanticscholar.org/paper/2365e67076e8cfffba013541521c21220532689e","s2PdfUrl":"","id":"2365e67076e8cfffba013541521c21220532689e","authors":[{"name":"M Sugimoto","ids":["2022073"]},{"name":"Y Suzuki","ids":["2185085"]}],"journalName":"Journal of biochemistry","paperAbstract":"A cDNA encoding Mucor javanicus alpha-glucosidase was cloned and sequenced by the reverse transcription-polymerase chain reaction and rapid amplification of cDNA ends methods. The cDNA comprised 2,751 bp, and included an open reading frame which encodes a polypeptide of 864 amino acid residues with a molecular mass of 98,759 Da. The deduced amino acid sequence showed homology of fungal and mammalian alpha-glucosidases and related enzymes, and the sequence around the putative active site was well conserved among these enzymes. The cloned gene was expressed in Escherichia coli cells to produce the alpha-glucosidase, which hydrolyzes not only maltose, but also soluble starch.","inCitations":["1705064da7edb8499d6ce92ef776efb33383dfee","dde51d434f9c9948aecc306b9ac74da0725de2e5","6753c958637957ae2eb2ca0c9d37cda67f28c8d9"],"pdfUrls":[],"title":"Molecular cloning, sequencing, and expression of a cDNA encoding alpha-glucosidase from Mucor javanicus.","doi":"","sources":["Medline"],"doiUrl":"","venue":"Journal of biochemistry"}

{% endhighlight %}
</div>

So it is clear that each line of these files is a JSON entry representing a different paper.
We are going to extract the actual key information into a julia structure.
Including tokenizing the abstract.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
@everywhere struct Paper
    title::String
    authors::Vector{String}
    year::Int
    abstract_toks::Vector{String} # We want that tokenized.
end
{% endhighlight %}
</div>

We define a loading function that takes file-name to load and a channel to output  to.
Like in the [earlier post]({{site.url}}/2017/11/18/Lazy-Sequences-in-Julia.html),
we are going to create a channel,
and load some of the data into it.
This dataset is huge, so using a channel to lazily load it is important.
Otherwise we'll use all our RAM for no real gain.
Loading items you never read is not useful.

It will parse the JSON, and load-up the data.
skipping any papers with no author or abstract.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
@everywhere function load_paper_data(ch, filename)
    open(GzipDecompressorStream, filename) do stream
        for line in eachline(stream)
            metadata = JSON.parse(line)
            all(haskey.(Ref(metadata), ["title", "authors", "year", "paperAbstract"])) || continue
                # skip papers without all the fields
            
            authors = [author["name"] for author in metadata["authors"]] # don't need there ids
            length(authors)==0 && continue # skip papers with no listed authors

            abstract_toks = reduce(vcat, tokenize.(split_sentences(metadata["paperAbstract"])))
            # First split it in to sentences which are tokenized, then concatenate all the sentences.
            length(abstract_toks)==0 && continue # skip papers without abstracts

            put!(ch, Paper(
                    metadata["title"],
                    authors,
                    metadata["year"],
                    abstract_toks
                )
            )
        end
    end
end
{% endhighlight %}
</div>

Ok, so lets see how that goes.


**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
ch = Channel(ctype=Paper, csize=BUFFER_SIZE) do ch
    load_paper_data(ch, datadep"Open Research Corpus/s2-corpus-39.gz")
end

collect(take(ch, 3))
{% endhighlight %}
</div>

**Output:**




    3-element Array{Paper,1}:
     Paper("Molecular cloning, sequencing, and expression of a cDNA encoding alpha-glucosidase from Mucor javanicus.", String["M Sugimoto", "Y Suzuki"], 1996, String["A", "cDNA", "encoding", "Mucor", "javanicus", "alpha-glucosidase", "was", "cloned", "and", "sequenced"  …  "hydrolyzes", "not", "only", "maltose", ",", "but", "also", "soluble", "starch", "."])
     Paper("An intensive motor skills treatment program for children with cerebral palsy.", String["Wende Oberg", "Barbara Grams", "Judith Gooch"], 2009, String["This", "article", "describes", "the", "development", "and", "efficacy", "of", "the", "Intensive"  …  "of", "assistance", "on", "short-term", "objectives", "as", "the", "program", "progressed", "."])
     Paper("Treatment of retinopathy of prematurity with argon laser photocoagulation.", String["M B Landers", "C A Toth", "H C Semple", "L S Morse"], 1992, String["Fifteen", "eyes", "of", "nine", "infants", "were", "treated", "for", "retinopathy", "of"  …  ".", "No", "intraocular", "hemorrhages", "occurred", "during", "any", "laser", "treatment", "."])     



## Serial Loader

To baseline this, I am going to define a function that loads all the files into a shared channel, in serial.
One after the other.


**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
function serial_channel_load(fileload_func, filenames; ctype=Any, csize=BUFFER_SIZE)
    Channel(ctype=ctype, csize=csize) do ch
        for filename in filenames
            fileload_func(ch, filename)
        end
    end
end

{% endhighlight %}
</div>

**Output:**




    serial_channel_load (generic function with 1 method)



And I'll define a testing harness

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
const all_corpus_files = glob("*.gz", datadep"Open Research Corpus");
function test_loading(channel_load, n)
    inchannel = channel_load(load_paper_data, all_corpus_files; ctype=Paper)
    collect(take(inchannel, n))
end
{% endhighlight %}
</div>

**Output:**




    test_loading (generic function with 1 method)



**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
@time test_loading(serial_channel_load, 1_000)
@time test_loading(serial_channel_load, 10_000)
@time test_loading(serial_channel_load, 100_000);
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
  8.302476 seconds (5.50 M allocations: 409.274 MiB, 3.67% gc time)
 82.545250 seconds (54.47 M allocations: 3.960 GiB, 4.37% gc time)
836.679749 seconds (537.63 M allocations: 38.729 GiB, 5.93% gc time)

{% endhighlight %}
</div>

## Asynchronous Loader

In theory, loading files Asynchronously should be faster than serial.
See [Wikipedia](https://en.wikipedia.org/wiki/Asynchronous_I/O).
This is on the basis that while the disk is seaking to the file I want to read,
julia cans switch the CPU over to another task which is wanting to do some computation.
Like parsing JSON.

Just to be clear 
async isn’t true parallelism, it is just swapping `Task`s when one is blocked/yields.
Only one bit of julia code runs at a time.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
function async_channel_load(fileload_func, filenames; ctype=Any, csize=BUFFER_SIZE)
    Channel(ctype=ctype, csize=csize) do ch
        @sync for fn in filenames
            @async fileload_func(ch, fn)
        end
        # channel will be closed once this do block completes.
    end
end
{% endhighlight %}
</div>

**Output:**




    async_channel_load (generic function with 1 method)



The `@async` starts the new tasks for each file.
The `@sync` needed to avoid exiting this loop before all the contained `@async`s are done.
The `Channel` does itself starts a task, to run that do block which starts up all the other tasks.
So  `async_channel_load` actually returns the channel almost immediately.
Most of the loading will happen as we try to read from the channel.

This is fairly simply now that it is in front of me.
But working out how to close the channel only once all the feeders was done took me a little bit.
The channel need to be closed once they are all done because
if the channel is left open the the consumer can’t tell that there is nothing left.
(and so you can’t use it with a for loop directly, only with `take`).

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
@time test_loading(async_channel_load, 1_000)
@time test_loading(async_channel_load, 10_000)
@time test_loading(async_channel_load, 100_000);
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
  8.954394 seconds (5.78 M allocations: 429.892 MiB, 4.39% gc time)
 83.615992 seconds (54.70 M allocations: 3.978 GiB, 5.03% gc time)
841.299898 seconds (537.86 M allocations: 38.746 GiB, 6.10% gc time)

{% endhighlight %}
</div>

You can see that we are not actually getting any performance gain here.
Infact, we are getting a small loss, though I am fairly sure that is below significance as other tiems I've ran this we get a small improvement.
I theorize that if we were reading from tens of thousands of small files, rather than 40 large ones we would see a bigger difference,
as in that case the hard-drive spends a lot more time moving around the disk.
But since it actually spends most of its time reading consecutive entries into the cannels buffer rather than seeking,
the async doesn't do much.

#### Note: zombie tasks
It is worth noting that because we are running `Iterators.take` to take a finite number of elements from the tasks, that we are potentially accumulating zombie tasks.
However, I believe they should all be being caught by their finalizers ones all channels they are pointing to are garbage collected.
It might well be better to be closing them explictly, but I have a lot of RAM.
(thanks Spencer Russell for suggesting I point this out)

## Distributed Loader
This is more fiddly.
But it is true parallelism.
If there is solid computation to be done on each item,
and the time taken to do the inter-process communication isn’t larger than the processing time,
then this is going to be faster.
If not all records are being returned (e.g some are skipped) then we know the interprocess communication time is going to be lower than the time to read from disk (since less data is being read).

With that said we are still IO bound, since the processes do all have to share the same physical hard-disk (or RAID array in this case)


**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
function distributed_channel_load(fileload_func, filenames; ctype=Any, csize=BUFFER_SIZE)
    Channel(ctype=ctype, csize=csize) do local_ch
        remote_ch = RemoteChannel(()->local_ch)

        c_pool = CachingPool(workers())
        file_dones = map(filenames) do filename
            remotecall(fileload_func, c_pool, remote_ch, filename)
        end

        # Wait till all the all files are done
        for file_done in file_dones
            wait(file_done)
        end 
        clear!(c_pool)
    end
end

{% endhighlight %}
</div>

**Output:**




    distributed_channel_load (generic function with 1 method)



This is a bit more complex. But actually not a lot once you’ve gronked the async version.
We wrap our local `Channel` into a `RemoteChannel` which can be sent to the workers (via closure) effectively.
We use a `CachingPool`, so that we only send `fileload_func` to each worker once (in case it is a big closure carrying a lot of data),
and we `clear!` it to free that memory back up on the workers at the end.

Rather than a loop of `@async` we have a map of `remotecall`s.
(this could be done a few other ways, including a using `@spawn`, but using that macro  it doesn’t seem to give much that `remotecall` doesn’t, and macros are intrinsically harder to reason about than functions (since they could be doing anything))
The `remotecalls` each return a `Future` that will hit the ready state once the `remotecall` has completed.
So rather than having an `@sync` to wait for all the enclosed `@syncs`,
we instead do a loop over the `file_done`
So we loop over waiting for them, to make sure we don’t close the channel before they are all done.
The loop of waits takes the place of the @sync.

**Input:**

<div class="jupyter-input jupyter-cell">
{% highlight julia %}
@time test_loading(distributed_channel_load, 1_000)
@time test_loading(distributed_channel_load, 10_000)
@time test_loading(distributed_channel_load, 100_000);
{% endhighlight %}
</div>

**Output:**

<div class="jupyter-stream jupyter-cell">
{% highlight plaintext %}
  9.660510 seconds (922.75 k allocations: 44.845 MiB, 0.45% gc time)
 16.911890 seconds (5.81 M allocations: 256.904 MiB, 8.95% gc time)
146.215262 seconds (52.69 M allocations: 2.264 GiB, 1.92% gc time)

{% endhighlight %}
</div>

Now, **that** is cooking with gas.

I hope this has taught you a thing or two about asynchronous and distributed programming in julia.
It would be nice to have a threaded version of this to go with it;
but making a threaded version of this is really annoying, at least until the [PATR work is complete](https://github.com/JuliaLang/julia/pull/22631).
I am very excited about that PR; though it is a fair way off (julia 1.x time frame).
Eventually (though maybe not in that PR), there is a good chance the threaded version of this code would look just like the asynchronous version.
