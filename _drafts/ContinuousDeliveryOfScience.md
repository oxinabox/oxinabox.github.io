---
layout: default
title: "The Continuous Delivery of Reproducible Science"
tags:
    - julia
    - jupyter-notebook
	- GoCD
---

Continuous delivery (CD) is a practice in software development of always having a deliverable product.
It means at any point in time someone can say give me the latest version, and you (the developer) can hand it over to them.

What does it mean to continuously deliverable science?
One of my friend's advisers (apparently) has the expectation that at any point in time he could call on any member of his lab to present on what they were doing, and that lab member would have a slideshow already prepared.
I think in general any decent researcher can with a bit of thought, and a white-board present a half-hour presentation on their latests developments -- though it might not be well organised or coherent.

This blog post is going to touch on open research, software development, and academia in general.
On a technical standpoint it is going to talk about [GoCD](https://www.gocd.org/), and []Julia](https://julialang.org/).
It's not going to be applicable to all science, and you'll have to spot where it doesn't apply to you.
Academia is to varied for me to claim to make statements that are universally applicable, or even for me to claim to recognise when they are not.
I hope though, that there is a take away for everyone here.

<!--more-->



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

