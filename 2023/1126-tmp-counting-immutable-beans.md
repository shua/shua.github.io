<pmeta id="created">2023-11-26</pmeta>
<pmeta id="title">TMP: Counting Immutable Beans</pmeta>

I have a lot of papers I want to get around to reading more deeply, so I'm going to try to encourage myself by implementing a weekly review, a la [The Morning Paper]

Intro
-----
Today, I'll be reviewing a paper from 2020 called [Counting Immutable Beans] by Sebastian Ullrich and Leonardo de Moura.
The authors present an automated memory management system based on reference counting ("RC"), which uses static analyses to reduce system allocator usage and infer RC operations.
This paper not only describes a theory, but contains some benchmarking results of their system vs similar systems in use, and since these guys are the some ones that work on the [Lean] language, this system was a basis for their rewrite of Lean from version 3 to 4.

The first thing you need to know when reading this is that there are 2 common approaches to automated memory management: reference counting, and garbage collection.
There is a tradeoff where reference counting has more runtime overhead, but has predictable runtime performance and simpler implementation, while garbage collection is more complex to implement, but gives more room for runtime performance optimization.
That's my summarization but of course there's a bunch of asterisks and people writing papers arguing that that's not quite true, this paper being one of them.
The authors argue in this paper that reference counting approach can be made performant with two techniques implemented as static program transformations.

Their approach takes a pure functional language with no concept of memory management (named `lambda_pure` in the paper), and maps to the same language but with added operations on RC'd variables (named `lambda_RC`).
They introduce two operations `reset`/`reuse` for reusing memory without invoking the system allocator to free/alloc new memory, which is their main trick for improving performance, and what they spend the first half of the paper describing.
There is an assumption here that invoking the system allocator imposes the majority of runtime performance overhead, which seems reasonable to me.

Reset/Reuse
-----------
In order to reuse existing allocated memory, you need to make sure no one else is using that memory, and that it is the right size.
The `reset x` operation checks at runtime whether `x`'s reference count is 1, in which case , if `x` isn't used anymore, `x`'s memory can be reused for something of the same size instead of being `free`'d.
The analysis to determine "isn't being used anymore" is named `D` in the paper (for "Dead", as a variable that will be used later is considered "live"), and the analysis for "later something of the same size needs memory" is named `S` (for "Substition").
The paper assumes that "number of arguments to constructor" is sufficient for measuring whether memory existing can be reused, and in any language where primitive values are all the same size this is true.
I'm used to languages like C or Rust, where primitive values all have different memory sizes, so this sounds foreign to me, but as I understand many languages, especially functional or scripting languages have no problem representing all values as some multiple of machine words, and any bit-packing is seen as totally optional optimization.

That's a high-level description of the general approach, but these `reset`/`reuse` operations could be stuck anywhere there is a variable.
So now we have two extremes of "no memory reuse", or "trying to reuse everything", both of which (likely?) have poor performance due to invoking the system allocator or introducing a lot of runtime checks.
This paper describes heuristics for adding checks to hopefully gain the benefit of reusing memory without the downsides of a million runtime checks.
They call it the "resurrection hypothesis" in the paper, and I understand it as:
when you want to construct a value, there's usually a deconstructed value of the same size right before.
This heuristic is then to add a `reset` check on deconstructed values, and then search forward for a constructor statement to insert a `reuse`.

Borrowing
---------
The automatic reuse of memory is the technique that is more novel to me, but the second technique is one I'm very familiar with: borrowing vs owning values.
The idea is that if a value is a parameter of a function, and does not escape that function call, then there is no need to `inc` the refcount before calling just to `dec` the refcount inside the function.
Users of [Swift] or [Rust] may recognize this technique.
Rust has a more complicated task of managing mutability, which a pure functional language doesn't have, and values escaping up the stack without being easily cloned (this necessitates all the lifetime annotations that users absolutely love /s) which this language also doesn't have a problem with because refcounted values can just increase the refcount.
The paper describes an algorithm for inferring borrowed vs owned parameters.
Interestingly, the language does not permit constructing general closures, instead allowing partial application of functions which makes the algorithm simpler but I don't think restricts expressibility.
(it feels like returning a closure can be rewritten as a global function that accepts all closed variables as parameters, and returning a partial application of that function, but I'm not 100% certain)

Further thoughts
----------------
One of the ideas that popped into my head is maybe implementing a Rust DSL which translates normal looking Rust syntax to a form where all function params are `Rc<_>`'d and the algorithms for this languages' `case` and `ctor_i` are translated to enum `match` and construction.
I'm not sure if the memory reuse checks are sufficient (as noted above, it's not generally true that the size of some constructed value is just `n` times the number of fields), but maybe something could be figured out.
I've read in Rust zulip threads and some dev blogs that it would be nice to have a way to
opt into some Rust syntax which doesn't require as much annotation to manage memory, and maybe this could help?
I enjoyed the read, and I'd recommend it to anyone thinking of implementing a pure functional language to think of ref-counted memory management and take a read themselves.


[The Morning Paper]: https://blog.acolyer.org/
[Counting Immutable Beans]: https://arxiv.org/abs/1908.05647
[Lean]: https://lean-lang.org/
[Swift]: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/automaticreferencecounting#Defining-a-Capture-List
[Rust]: https://doc.rust-lang.org/stable/book/ch04-02-references-and-borrowing.html
