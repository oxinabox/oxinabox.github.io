title: Big-O complexity of humans
layout: default
---

This is some musings on Big O complexity of human interaction.
It focuses on time and money, which as they say, are the same thing.
I first noticed this when GMing tabletop RPGs.
I am used to games with 5 or 6 players and it moves sedately.
Maybe even below real-time as people argue about what to do.
Then I started a game with just 2 players.
They blitz through everything, making and executing plans, and then moving on, to the next all in 1 session.
So I started to think about how more humans introduce delay.



The important part of Big O complexity is it ignores constant factors and lower-order offsets.
In human interaction terms that mean that if there is a fixed change of something happening, we can consider it as if it always happened.
So in the presentation example that follows, I will mention that each audience member asks a question `O(n)` questions.
In real meetings that doesn't, maybe only 1% of people ask questions and maybe 0.1% ask two. But it doesn't scale with the audience size so it is a constant factor.
Under Big-O complexity `O(0.011*n)` is the same as `O(n)`.


## On presentation and meetings.
I said in the introduction:
A typical presentation, that allows questions from the audience has time complexity `O(n)` where `n` is the size of the audience.
If you time-box the presentation and stick to schedule and refuse questions then that becomes `O(1)` time taken doesn't scale.
If it is a panel discussion with `t` participants, taking questions then it is `O(n*t)` if each answer once,
but if it triggers a good back and forth between panelists,
then each will (potentially) respond to each primary point made by the others, and so it will be `O(n*t^2)`.

The time taken for a typical meeting is at least quadratic in the number of participants.
For much the same reason.
If each participant spoke on each topic of discussion then it would be `O(n)`.
However, a meeting basically needs to be a multi-way conversation,
so people need to respond to the responses so `O(n^2)`.
If we then have responses and discussion moves goes off tangent,
then we have that factor increase `O(n^p)` where `p` is the tangent factor.
Good chairing of a meeting limits `p` to some valuable level.

## On the value of work

Standard employees are paid linearly for time.
Do 1 days work get 1 unit of pay.
If I work on a car assembly line, then I produced linear value for my employer.
I build 1 car today, the company sells 1 car,
tomorrow I build another car and the company sells 1 car.
If on the other hand I were an engineer, designing cars:
then today I design a car and the company makes and sells 1 car,
tomorrow I design a new car and the company makes and sells that, but they are also still making and selling the one I designed yesterday, so today they can sell 2 cars.
Tomorrow I design another new car, and now they are selling 3.
As an engineer I produce quadratic value.

(This is not to bag on assembly line workers: Holistically, the company is a quadratic value producing enterprise.
Without the assembly line worker it wouldn't matter how many cars were designed.)

So an interesting thing about software development, is that you have a lot of engineers.
Basically, all software developers produce quadratic value.
Software maintenance is quadratic value as it fixes bugs for all customers.
On the other hand training and answering support calls is only linear value.
But producing training material is quadratic value.

It is interesting to thing about what gives cubic value.
Recruiting software engineers does.
Training people in automation does.
