<pmeta id="created">2024-01-15</pmeta>
<pmeta id="title">TMP: Abstraction-Safe Effect Handlers via Tunneling (pt 1)</pmeta>


Today, I'll be talking about a paper I found, as often happens, in the references of another paper.
[_"Effect Handlers, Evidently"_][evidently] was the first paper I came across, again from the research group around the Koka language (some of whom had a hand in a previous week's [fipfp]), and it presents an approach to limiting the scope of a language construct, arguing that this limitation allows for better programmer comprehension and machine compilation of the resulting language.
For some background, "algebraic effects" have been gaining popularity in the programming language design space, as a way of capturing concepts like "this function may read user input" or "this function may fail with an exception" or even "this function may change its answer randomly to the same input" in the written syntax (and operational semantics) of the program.
The reason effects are gaining popularity is because the alternatives, mainly doing nothing and monads, have their papercuts that effects don't seem to struggle with.
Effects however, have their own papercuts which these two papers try to salve.
[_"Abstraction-Safe Effect Handlers via Tunneling"_][tunneling] is referenced by the previous paper, and I think does a better job of showing the programmer comprehension issues with unscoped effect resumptions, but also presents an approach to limiting them, but with less of a focus on machine compilation.

This second paper is the one I'd like to dig into today.
I can't say I will offer a lot of insight, but maybe reading along with my struggles in understanding will be helpful to others.

[fipfp]: ../2023/1210-tmp-fipfp.html
[evidently]: https://www.microsoft.com/en-us/research/publication/effect-handlers-evidently/
[tunneling]: https://ecommons.cornell.edu/items/988aacdc-a8b5-487e-8cfe-166623f390e5

Introduction
------------

Again, if you are unfamiliar with algebraic effects, you may still be familiar with exceptions in a language like Java, Python, C++.
Exceptions are usually thought of as a specific application of algebraic effects, but a lot of the research around effects borrows syntax from existing work on exceptions.
So you might have `fn(x: int) -> int throws MyEffect` as a function signature for a function that takes an int, returns and int, and might perform operations from `MyEffect`.

<!--
Starts off well, explaining some of the issues with current effect systems where you have to decide between shallow/deep and which handler
Not modular, functions can tell whether a handler is used inside another function by whether effect bubbles up or not.
-->

The motivating example from the paper assumes we have some `Tree[X]` data structure, and `Yield[X]` effect. Assume we have two functions that take can be used to calculate the size, then they should both do the same thing, but here we notice some funny behaviour:

    // fsize1 and fsize2 are just slightly different ways of calculating the number of elements in the tree that satisfy some effectful predicate (function that returns a bool)
    // I'm hiding the body of the functions for effect, but I'll show them later
    fsize1[X,E](Tree[X], X → bool / E) : int / E { ... }
    fsize2[X,E](Tree[X], X → bool / E) : int / E { ... }
    f(x: X) : bool / E { ... } // some predicate
    // wrap the predicate in one that yields so we can add our own behaviour
    val g = fun(x : int) : bool / Yield[int] { yield(x); f(x) }
    
    try { fsize1(tr, g) }
    with yield(x : int) : void {
      print("inside fsize1: ", x)
      resume()
    }
    try { fsize2(tr, g) }
    with yield(x : int) : void {
      print("inside fsize2: ", x)
      resume()
    }

If `fsize1` and `fsize2` are defined in some external library that we're pulling in, then we don't have access to the body of the function, but it shouldn't matter because the signatures are the same, right?
For some reason, running this only prints out the "inside fsize2: " lines, where we'd expect either to print both "inside fsize2: " and "inside fsize1: " or neither.
The problem is that whoever wrote `fsize1` uses the `Yield[X]` effect internally, as below:

    # helper to yield any value x in tree tr for which f(x) is true
    fiterate[X,E](tr : Tree[X], f : X → bool / E) : void / Yield[X], E {
      foreach (x : X) in tr
        if (f(x)) { yield(x) }
    }
    
    fsize1[X,E](tr : Tree[X], f : X → bool / E) : int / E {
      val num = 0
      try { fiterate(tr, f) }
      with yield(x : X) : void {
        ++num; resume()
      }
      return num
    }
    
    fsize2[X,E](tr : Tree[X], f : X → bool / E) : int / E {
      val lsize = fsize2(tr.left(), f)
      val rsize = fsize2(tr.right(), f)
      val cur = f(tr.value()) ? 1 : 0
      return lsize + rsize + cur
    }

We had no way of knowing `fsize1` does this because again it's assumed this is some library code we can't read, we only have type signatures, and those don't mention `Yield[X]` at all.
Being able to write `fsize1` and `g` separately without each having to know the internals of the other is related to a concept of code modularity, and the authors argue that modularity is broken by this behaviour of naive effect handling.
In the paper, they present a language and rules which make code like this easier to reason about statically (ie without running it, just looking at source) and which they argue preserves the modularity.

This isn't the only paper to present a solution to this problem, nor is it the only one that solves by limiting the search for effect handlers, but I thought the examples were pretty succinct and sort of realistic, so I can recommend.

Syntax/Semantics
----------------

The magic of their approach is limiting the handling of effects to certain scopes using capabilities.
Capabilities are little labels that are used to track what functions are allowed to be evaluated where.
So in the above example, we want to say that only certain effect handlers should be used to handle the effects in certain functions.

I have an issue though, the way the specify handler to effect-operation-performing code is by introducing a label `l` around some scope, and tagging the handler definition with that label.
I am having trouble translating their example code language into their formal syntax:

    e   ::= a | l | hh.lbl                                 (capability effects)
    T,S ::= 1 | S->[T]_e' | all a. T | Pi h:FF [T]_e'      (types)
    h,g ::= hh | H^l                                       (handlers)
    t,s ::= () | x | \x:T.t | t s | let x:T = t in s |     (terms)
            /\a.t | t [e'] | \hh:FF.t | t h | UP h | DN^l [T]_e' t
    H,G ::= handler^FF x k. t                              (handler definitions)
    
    FF: Effect names   l: labels   a: effect vars   hh: handler vars   x,y,k: term vars

They also mention

> The `try-with` construct corresponds to terms of form
> ```DN^l [T]_e' (\hh:FF.t) H^l```
> ...
> the following term corresponds to associating two handlers with the same `try` block
> ```DN^l [T]_e' (\hh1:FF1.(\hh2:FF2.t) H2^l) H1^l```

which _I think_ means the labels are generated as sort of unique tokens.
So, let's try to translate ```try{ fsize1(tr, g) } with yield(x: int) void { resume() }``` to their syntax:

```
DN^l [T]_e' (\hh:FF. fsize1[X, E](tr, g)) (handle^yield x resume. resume ())^l

// where does the `hh` go?
```

Further in the paper, they describe how mention of effects in the fn signature introduces an inferred handler variable.

```
val g = fun[h: Yield[int]](x: int) : bool / h { h.yield(x); f(x) }
try { fsize(tr, g[H]) }
with H = new Yield[int]() { yield(x: int) void { ...} }
```

which I guess makes `g[H]: int -> bool / H` but...I'm also not sure how to translate that into their formal type syntax, maybe `g: Pi h:FF [int -> bool]_e'`? Should `FF` be `Yield[int]` here or just `yield`?

```
let g = \h:Yield[int]. \x: int. let _: () = h x in f x
```

I guess we just assume that the formal language is only for effects with a single operation, so the question of `Yield[int]` or `yield` is not important because there is no polymorphic effects like `Yield[X]` in the core language, and all effects have a single operation?

The other question I have is: where is the effect function and application (`/\a.t` and `t [e']`) used?
A lot of the examples use _handler_ function/application (`\h:FF.t`/`t h`) but only two of the examples in the proof section use the effect application, so I'm not sure what that is for.

Enough
------

I think this is long enough for now, I will return next week, hopefully with answers to these questions, and more!
