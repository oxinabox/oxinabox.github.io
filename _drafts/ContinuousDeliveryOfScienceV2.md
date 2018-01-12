---
layout: default
title: "The Continuous Delivery of Reproducible Science"
tags:
    - julia
    - jupyter-notebook
	- GoCD
---

Continuous delivery is a practice in software development of always having a deliverable product.
It means at any point in time someone can say give me the latest version, and you (the developer) can hand it over to them.

What does it mean to continuously deliverable science?
One of my friend's advisers (apparently) has the expectation that at any point in time he could call on any member of his lab to present on what they were doing, and that lab member would have a slideshow already prepared.
I think in general any decent researcher can with a bit of thought, and a white-board present a half-hour presentation on their latests developments -- though it might not be well organised or coherent.

This blog post is going to touch on open research, software development, and academia in general.
On a technical standpoint it is going to talk about [GoCD](https://www.gocd.org/), and []Julia](https://julialang.org/).
It's not going to be applicable to all science, and you'll have to spot where it doesn't apply to you.
Academia is to varied for me to claim to make statements that are universally applicable, or even for me to claim to recognise when they are not.
This is mostly aimed at empirical computer science, and the computational sciences (e.g. computational biology, where they run many simulations.).
I hope though, that there is a take away for everyone here.

<!--more-->

## A Dream
Let me tell you a dream.
This is an idealised scenario, and on very few projects will it actually be realisable.

 - You make a change to your algorithm
    - just a small hyper-parameter tweak, that you tested locally on your and got a small improvement.
 - You commit it to github (or your version control of choice)
 - It a CI server reruns all your **unit tests**
    - Proving your algorithm still works the same way.
	- Proving that everything isn't broken.
	- This happens in <10 minutes
 - A **replication build** is then triggered
    - It runs all your simulations, tests convergence, checks benchmarks etc.
		- This runs for however long it takes, could be minutes, probably is hours, might be days.
	- when the simulations are done, your statistical analysis scripts runs (be it in R, Julia, Python/Pandas)
	- The results of your analysis scripts are the key **tests** at this step.
	- These tests check that basically your results are getting better.
 - A **publication build** is triggered, to update your write up
	- The statistical analysis is already done in the previous step
		- it has spit out some CSVs of data 
		  - useful with [pgfplots](https://ctan.org/pkg/pgfplots) and [pfgplotstable](https://ctan.org/pkg/pgfplotstable)
		- Maybe it has output a visualisation as a `.svg` or `.png`
	- LaTeX runs, it creates an updated copy of your paper draft with the new figures and numbers
	    - You know your text is still fine, as your tests in the previous stage would have failed if the results were too different.
	- It also updates your slide show 
	    - but actually you don't care as that slide-show you made for showing someone weeks ago and don't have any plans to use again.
		- It gets updated anyway, because it is automated, and there is zero effort involved.
	- [latexdiff](https://github.com/ftilmann/latexdiff) runs, producing a PDF with the differences highlighted.
	    - This isn't very useful this time, since it was just a change to the results.
		- But if your commit had have been rewriting the text it is very handy
 - Your co-authors notice that a change has been made and download the latexdiff from a dash-board
    - They are pleased, and buy you a cake.


This is a nice story.
You are continuously delivering science.

While it is only a replication, not an independent reproduction, it is still very good.
The fact that it is automated mean that it should be no problem for someone else to get it working on there computer.
It also makes it very clear the full path from which all your results come from, so anyone checking can see you are not just making up numbers.
If you use version control consistently (and don't cheat), it is even relatively clear that you are not cherry-picking datasets, or results.
This dream isn't real ... yet.

## The state of the art: CI in Julia

Julia has great CI by the standards of an research ecosystem.
Every registered julia package (and many unregistered once), has CI setup to run their tests.

The normal way to create a julia package is `PkgDev.generate`.
This immediately sets you up with the configuration files for CI on [TravisCI](https://travis-ci.org/)
and AppVeyor(https://ci.appveyor.com/).
To turn on CI testing you just need to go into the TravisCI and AppVeyor settings page and enable them on the repo.
All that is left is to write your tests.

`PkgDev.generate` also enables test coverage reporting from [CodeCov](https://codecov.io/) and [Coveralls](https://coveralls.io/).
It sticks a badge in your readme, saying what portion of your lines are ran during tests.
While lines-of-code test coverage isn't a perfect metric of how well tested a package is,
having it reported certainly "guilts" you into writing some tests.
No-one likes seeing their coverage go down.




## Problem: making your code portable
One of the major inhibitors of getting code running on CI,
and of having reproducible science, is that the experimental code might not run on other peoples machines.

### Software Dependencies
If you need to install software to get your project to run, that makes it much less portable.




### Hardware Dependencies

If your code needs to run on a super-computer, it is not portable to a normal computer.
Well it might be, but it might take years to run.



### Data Dependencies
(Most) Research code runs on data.



The path to data being hard-coded into a script is pretty common.
This is pretty bad, but it makes running the code on one computer easy since you just run the script.
Conversely, if you don't hardcode it, but have it as an  argument passed in on the command-line
then now it is annoying to run the script as you need to work-out the path.






## Problem: You can't touch your test data
Good machine learning researcher's know to stay as far from their test data for as long as possible.
Ideally, you do all your development on the training data, and on your so-called development data.
Development data being some data you are treating as test data.
Possibly the development data is specified for the data set,
possibly you are sub-setting it out of the training data (e.g. 10 fold cross-validation).
In the ideal world you only ever use your test data once.

Running multiple tests against the test data risks leaking information.
The reason we don't train on our test data in the first place is that we want to make sure our model extends to input's we have not seen.
By running repeated tests against the test data, and adjusting the hyper-parameters each time,
you are allowing information about the test set to enter your model.
Thus weakening the strength of your ability to know how well it will generalise to the real world.

More generally this even applies (over a longer time period) to standard datasets used by multiple researchers.
Information can be leaking because papers that have ideas that do well on these benchmarks are read, and then extended upon.
For this reason there are calls to stop using some datasets.
In NLP, there have been calls to stop using the Penn Treebank Wall Street Journal section for evaluating parsers.
For computer vision, similar calls have been made for MNIST (though MNIST has other problems like being too easy).
In that space, [Fashion-MNIST](https://github.com/zalandoresearch/fashion-mnist) is a cool drop in replacement.
Over used of benchmark datasets leaks data not (only) through the hyper-parameters, but into the algorithms themselves.
But this is going off-topic, the main issue is leaking data to yourself though hyper-parameters.

In the ideal world, you development your work fully without touching the test-data.
You even write the paper.
Then at the last minute you rerun everything test-set and update the paper.

This is in-fact *not* a problem in our dream continuous delivery of science setup.
It is made easier.
We just add an additional separate, manually triggered CI step.
That runs after the **replication step build**, using the model that was trained there,
and uses the test data -- and then triggers the **publication build**.
While automating this (as something you do once) is kind of pointless, it is also trivial.
If you've written your code the right way it just involves changing an environment variable.














## Two ways to stop your ideas being stolen

People are often worried about their idea's being "stolen".
That someone else might take their idea and (in some way) profit from it before they can.
Ruining it for the ideas creator.
The creator vanishes in obscurity, while the thief goes on to ever greater heights.
To combat this, academics use two main strategies.
Tell No-one, and Tell Everyone.

### Tell No-one

Tell No-one is the traditional and obvious solution to stop your ideas being stolen.
It doesn't mean literally tell no-one, but it means sharing it only with a trusted group, until you are ready to fully capitalise on it and extract profits.
In this case capitalising on it means publishing a paper.

If you're really paranoid, it means publishing a series of papers in quick succession.
That is to say first you publish a paper about your main idea.
Then as soon as that is accepted you submit for example a paper extending it to a related area, and a paper applying it to several problems, etc.
That way no-only does no one get to profit from your core idea, they also don't get the "easy" profits from applying your idea to other problems.
As before anyone else knew about it, you had already written the other papers.

Tell No-one means your keeping your ideas to you until your ready to release them.
No-one can steal an idea they're not aware of.

### Tell Everyone

The opposite of Tell No-one is Tell Everyone.
This might seem counter intuitive.
How is telling everyone your idea going to stop it being stolen?
It stops it being stolen because you're establishing that that idea is yours.
If everyone knows that you had an idea on a particular date,
for example you pushed out an prototype implementation onto Github, then they can't claim it as their own.
If you have a paper-preprint on Arxiv, they certainly can't.

Plagiarism is a distinct notion from copyright violation.
While one can license away ones copyright given rights, via open-source licenses and public domain dedications, doing so doesn't let them use your work without crediting you.
While releasing something (a paper or some code) lets normal uses happen without crediting you,
it doesn't allow for an academic paper to be written.
That is to say plagiarising something that is public domain (let alone something that is merely open-source) is still academic misconduct.
That kind of thing gets you blacklisted from journals and really hurts your reputation.
It is the responsibility of anyone using your work to credit you.

Of course this is only a limited kind of protection.
You can't actually hunt-down anyone who might have stolen your idea.
It also doesn't let you horde the follow-up application papers.
Getting citations to a draft in a Github repo isn't going to advance your career much.
Getting acknowledges at the end of a paper even less so (no automatic tracking services for acknowledgements of people AFAIK.)).

## Ideas are cheap
Here is the thing though.
Ideas are really cheap.
I have dozens of new ideas every week.
Most of them are probably bad.

I don't have time to try them all out to see if they are bad.
No-one does.
So if someone steals your idea they have stolen anything irreplaceable.

Even if they take that idea and go big with it

