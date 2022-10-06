
In my current gig, we've been working on a kind of greenfield, and a lot of questions have come up around what is the right way to do X.
I try to document some of my decision making tools, for any given X in a project, how I decide what is the best thing to do.

In this particular case, I am talking about a golang-based distributed application, with currently 2 main services.
I imagine a lot of the advice can be extended to other domains with varying success depending on how specific it is.

# Should we put this in a package?

I like casey muratori's post on semantic compression, and while I'm not thinking about it all the time, I just wanted to mention it.
I tend towards inlining things, and encouraging refactoring later when it's needed.
At my last job, it often felt like refactoring never fit into the current planned sprint work, and there's a mental block on creating "extra" tickets in a sprint, so people would avoid refactoring things.
The last project I worked on was a pretty established codebase, with a lot of hands touching it, and a lot of half-finished refactors to fit one or another style of code architecture.
This led also to people wanting to avoid any refactor that took more than a day or touched more than one file, because everyone felt the pain of having to keep 3 or 4 different patterns in their heads while reading through a callstack, and didn't want to add another.
I tried to argue for this, and to point out that everyone agreed this was a problem, but the best we had was "if you can define the refactor you want to do during sprint grooming, then we will add a card and  vote on it, otherwise just try to add it to whatever ticket you're working on".
This mentality, I feel, fails to recognize that a lot of code refactoring is simply feeling like something is wrong without knowing exactly how to fix it, and it often requires a couple attempts before you really land on a change that feels like an improvement.
My solution was to toe the line of getting sprint tickets done and getting the refactors I wanted to do done.
I think I managed that, and my work was appreciated by the team, especially the refactors that often ended up in simplifying and deleting a lot of code.
The most gratifying is tracing every route through some old complex code and realizing that you *can* delete it.
It often requires little effort to add code, but a *lot* of mental effort to delete it.

# New vs old projects

In the current job, everything is from scratch, so there's a much greater feeling of freedom.
For better or worse, we don't feel like we're adding to our problems if we don't make the code right the first time.
We don't have as much of a push to work exclusively on features either, and we're all original authors, so we *all* feel like we are able and allowed to spend some time on complex refactors.
I think a key takeaway I had working on both projects was that I think rules around code quality and sprint planning should be different for different stages in a project.

Starting from scratch, and lacking strict pragmatic or theoretical guidelines, I don't believe code review should be strict.
Some people start projects from strict theoretical base, in which case they can create very clear and strict rules for reviewing and building the code, but most of the projects I've been working on, the "best practices" are something that comes from having an existing codebase and seeing what you like and don't like.
So you can point out stuff you like or don't like, but code is allowed to be bad.
There must also exist an understanding that time *will* be spent later cleaning it up.

# Nitpicking

I think there's a mental block around "pestering" people with nitpicks.
I've also noticed that if I've reviewed a PR a couple times and I still have a lot of nits, at a certain point I'm worn down from nitpicking and instead chalk it up to "I'll clean that code if it bothers me in the future".
This mentality probably only works if I'm either an exceptional pedant, or if the people I'm working with don't have standards of code quality that are too different from mine.
For the first case, I may *think* that a million things could be better, but when the code is committed, I never have any practical issue with it so the code stays as is.
The second case means that nits do make it to the main branch, but they get through at a slow enough pace that I or my coworkers do refactors at a rate that is sustainable with the amount of difficult code that's merged.

# Ascii-diagram editor

I'd like to build an editor for ascii diagrams.
   ,-----------.
   | something |-.
   '-----------' | ,------.
,------.         '-| this |
| like |-----------|      |
'------'           '------'

should the graph be generated from some markup language (mermaidml, plantuml), or do I want to edit ascii?
I would like to just do ascii, because the benefit for me of ascii diagrams is that I see them in any monospace formatted output
I'm fine with interpreting blocks of ascii as some kind of vector-graphics, lines, text, etc; and trying to edit it as such.
Alternative is to interpret diagrams: nodes, lines, labels, but that leaves me in a rut with any diagrams that are slightly off.

So, what are my primitives? line, label
select:
	1 --- ask left, right, or stop
		^
	2 |
	  |< ask up, down, or stop
	  |

	3 >,- ask right or down
		|

	4 -.< ask left or down
		|

		|  ask up or right
	5 >'-

		|
	6 -'< ask left or up

for 1 and 2, continue til you hit different character

move:
	1 ._ <-> -.
	2 _, <-> ,-
	3 _ <-> .
	  .     |
	4 _ <-> ,
	  ,     |
	5 _'# <-> '-#
	6 #'_ <-> #-'
	7 ' <-> |
	  _     '
	8 |_ <-> _|
	9 - <-> _
	  _     -


# working remote

My last job gave me the ability to work remote whenever I wanted to.
We had an office, and I had a desk and could be surrounded by coworkers, but if I didn't feel like making the commute, there was not really any shame to it.
I think there was still some pull to work around colleages, especially, people I enjoyed working with or talking to, but it was unexpected and really nice.
At the time I thought a lot of jobs could and should be changed to allow working remote.

There were some downsides, and if the team you worked with wasn't open to it, you'd run the risk of pestering everyone to accomodate your workstyle to make full remote work.
For instance, meetings happened often enough in person, and if you were meeting with people from outside my group it wasn't as reflexive to open up a webex or hangouts call and broadcast the meeting link
in a slack channel.
So often enough, I would be left out unless I knew a meeting was happening and could ask someone to open a call, or someone from my team was in the meeting and thought to ask.
Similarly, "water-cooler" conversation was lost working remote, replaced mostly with IRC chat, which I haven't found to be the same even in 100% remote groups.

# logic programming

I decided this most recent advent of code to complete all the puzzles using prolog, specifically [scryer-prolog].
I managed to complete a fair number of them, though I failed to complete even the first part of around 5.

When I did manage to complete one, it didn't take too much work to optimize the solution to less than one second, except for a handful of cases.
Completing all of them in less than 1 second was not a goal of mine, and I don't even know if the optimization is there to do that.
The lack of bit operations on numbers or access to contiguous memory meant that every boolean value was a full number, and every array of things to N\*2 space in memory (for cons style list), and access was O(N), so...not great.
There's still a couple problems where I just can't figure out a way to store and access the data such that any iteration over it finishes in any reasonable time.
Maybe making use of some scryer built-in types like the assoc array could help.

I didn't really have many "aha" moments with logic programming this time around, and the problem set doesn't really lend itself to selecting a single correct solution from a large problem space.
Mostly it was knowing good data structures and algorithms, and adapting them to match the tools I had (ie lists, recursion).
I think reforming some of the data from flat lists to n-ary trees might improve runtime, but I haven't checked.

When hitting the wall on some problems that I had a "correct" solution, but not a performant one, I started branching out and tried to see where logic programming has come since the 70s and where might it go.
I've seen some links to [mercury] as a more typed version of prolog.
In a different vein, I see [Z3] and other SMT solvers mentioned as stronger tools in a specific subspace of Prolog.
Lastly, the field of [answer-set programming (ASP)] and the tool [clingo] have come up.
Clingo is the only one I've rally tried to dig into, and I will say, I still don't really understand how I'm _supposed_ to use it.
By that I mean, I try to write things that are simple prolog or functional data structures, and clingo hangs.
