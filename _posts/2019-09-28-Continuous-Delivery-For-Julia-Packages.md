title: Continuous Delivery For Julia Packages
tags: julia
---

TL;DR; Every Pull Request should increment the version number in the Project.toml,
and then you should register the release immediately after merging.
Why do this? Because people are making PRs to your repo because they want that change.
Don't make them wait for you to tag a release.
Also for all the normal advantages of continuous delivery.
<!--see more-->


When Julia-1.0 and Pkg3 came out over a year ago,
and the more recent (but still many months ago)
change over from REQUIRE to Project.toml for the [General Registry](https://github.com/JuliaRegistries/General),
all started [taking SemVer seriously](https://semver.org/).
And that means we can continuously release packages,
without worrying about breaking anyone's code.

The majority of packages are specifying compat bounds (and in my opinion all should),
using the [SemVer based specifiers](https://julialang.github.io/Pkg.jl/dev/compatibility/#Version-specifier-format-1) in the Project.toml.
(Rather than just lower bounds, which is what people used to do in the REQUIRE days.)
This means that if you tag a new release as breaking, no existing package will see it,
until they are ready -- which they show by updating their compat bounds.

Note that in Julia's extension of SemVer, incrementing leading non-zero marks a breaking change.
So even packages still on v0.x.y are still safe to depend on with compat bounds.

So continuous delivery is safe.

## Required for Continuous Delivery
Continuous delivery requires a few things up front.

### Automated Tests:
 Julia has a pretty solid Test standard library, and a bunch of packages like [ReferenceTests.jl](https://github.com/Evizero/ReferenceTests.jl). If you are not already doing this then get on that before all other things. You don't need to go all in on test driven development if that isn't your thing. But at very least get some basic test coverage. Because Julia is not a static language, the compiler will not catch basic errors like typos, you need to run the code to get that. (Or run some static analysis, but you would trigger that in your tests.)

### Continuous Integration:
Something needs to run your tests, on every PR.
Everyone really should be using [PkgTemplates.jl](https://github.com/invenia/PkgTemplates.jl), to create new packages.
It will setup the config for [TravisCI](https://travis-ci.org/), [AppVeyor](https://ci.appveyor.com/), and [CirrusCI](https://cirrus-ci.org/), plus setup Documentation and other good things.
All you need to do is enable the repos on your account with your favorite CI service.
Existing packages can find and copy the configs easy enough.

Also something needs to deploy your docs after you make a release.
And Documentor.jl has instructions for setting up TravisCI for that.
And PkgTemplates, as I mentioned, will set most of that up for you, barring the deploy keys.

### Work broken into small chunks
This is the standard way to work in open source.
You get 1 new feature or bug fix per PR.
It gets reviewed, then merged.
If you are not using PRs like this, on your projects,
you'll need to switch to it.
It is a good way to work, even on personal projects.


## So on to how to do this:
When someone (including you as the maintainer) make PR to your repo,
you have them include in the PR the appropriate change to the version number,
for if it is patch, a new feature, or a new breaking feature.
(Or if you are still in 0.x.y just for if it is nonbreaking or breaking)

Then immediately after merging the PR, [tag a release.](https://github.com/JuliaRegistries/Registrator.jl#how-to-use)
Hopefully, soon after that release merged into General.


## What if I don't want to release right now?
There are not many good reasons to hold off on a release after merging in a PR,
but there are some.
Main one I can think of is if that if you know a group of breaking PRs are coming in soon,
and you don't want to tag a bunch of breaking releases, because it would mean your packages users would have more versions to work through in their own packages Compat sections.

In this case the best thing to do is to change the version number to what it would be
but add a `-DEV` suffix, e.g. `2.0.0-DEV`.
Rather than leaving it at `1.7.2` which would be a lie, since it has had a breaking change.
Also better than changing it to `2.0.0` and not making a release since that gets confusing since you need to workout which versions in the Project.toml are released and it is just a mess to think about.

A nice feature for testing.
While you can't register packages with a `-DEV` (or other prerelease markers),
you can still install them via `pkg> dev MyPackage`, into a project.
And julia will treat `2.0.0-DEV` as compatible with `2.0.0` in the `[compat]` section of the `Project.toml`.
This is a bit odd, since `v"2.0.0-DEV" < v"2.0.0`, but practically it is quite useful.


## What if I mistakenly make a breaking release.
If you happen to push a change that was breaking, then it isn't the end of the world.
Since you are releasing more often, people will see it sooner, and thus open an issue sooner.
The correct thing to do in these circumstances is `git revert` the PR the introduced the change,
then tag a new patch release,
then either workout how to reintegrate that change in a nonbreaking way,
or re-apply the PR and tag a breaking change.
Tagging the patch release means that people can update and they will see what is effectively the same code as before the PR.
The package manager will see the fixed (reverted) code as the better (higher) semver than the mistakenly broken one.

## Why do this?

In enterprise Agile continuous delivery is a well-established practice that you can read a bunch about. So I am not going to talk about that here, you can google for it.
In open-source there are additional advantages: _you avoid annoying your contributors._
There are few things as frustrating as someone opening an issue on one of my projects that is due to an upstream bug in one of my dependencies,
me opening a PR on that package to fix it and getting the PR merged,
and me thus considering the issue resolved moving on.
Only to have a new identical issue opened a few weeks later,
because no release has been tagged upstream in 3 months.

Your contributors are making PRs because they want the feature/bugfix.
You have already indicated you are happy with it by merging,
why hold off releasing it to the world?







