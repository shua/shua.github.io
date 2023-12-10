<pmeta id="created">2023-12-9</pmeta>
<pmeta id="title">TMP: Fully In-Place Functional Programming</pmeta>

Continuing the theme from [last time][tmp-beans], I'll be reviewing a paper related to static memory management.
This one's a little newer, and a bit longer as well, so I wasn't able to get through the whole thing, but hopefully this serves as good notes for the next time I read it.

The paper I'm reviewing is titled ["Fully In-Place Functional Programming"][fipfp] by Lorenzen, Leijen, and Swierstra.
Similar as well to last time, this paper describes a practice the authors use in a real programming language, this time [koka] from microsoft research.

Something new
-------------

While ["Counting Immutable Beans"][tmp-beans] contributed the insight that often times an alloc follows a free, this paper contributes a language where we can guarantee that.
As I read through this, they make a lot of references to [Perceus] and the Counting Immutable Beans paper.
I think [Perceus] is the paper that links the [beans][tmp-beans] paper with this one, as it describes (as I understand, haven't read it yet) a performant reference counting garbage collector.

If you really like programming language theory proofs, I don't know if I can offer any more insight than if you just read the paper.
If you're not interested in the proofs, it feels this paper's main contribution is to tie together a bunch of different ideas into one nice, theoretically sound box.

So the ideas pulled together are:

- alloc-fusing heuristic, and borrow params from ["Counting Immutable Beans"][tmp-beans]
- better ref counting, and the initial "functional _but_ in-place" (fbip) idea from [Perceus]
- linear reuse credits from work like ["Type-Based Amortised Heap-Space Analysis"][hofmann-2006] (that's one example of a lot of similar work from hofmann et al)

I'm going to write the rest of this post more about why this paper's results are so useful, rather than describing the bulk of the paper which is proving things about their language.

Prerequisites
-------------

This paper tackles a problem of memory management, and describes a language for which it can be proven that no memory is allocated or freed during evaluation.
This is useful, as memory allocation is often the source of inefficiencies either in use of computer memory or in slowing down computation.
This is something that is easy (enough) to do with a very limited toy language, but the language presented in the paper is expressive enough to encode complex and useful algorithms.

Of more theoretical use, the fact that this language is "functional" means it is much easier to mathematically prove things on.
If you are unaware, there are two dominant styles of programming languages and algorithms: imperative and functional.
It is easier to give examples than define what these things mean, so that's what I'll do.
Take for instance the following problem: we have a list of numbers, and we'd like to reverse it, so the last element becomes the first, the second-to-last becomes second, etc.
With an "imperative" style, we would model the list as a block of contiguous memory, and we could swap the outside moving in.

Memory management and functional programming
--------------------------------------------

I will give an example of an imperative program that allocates and deallocates more than necessary and a small optimization to make allocation constant.

    xs = alloc(4);
    xs = [4, 3, 0, 7];
    i = alloc(1);
    i = 0;
    while (i*2 < 4)) {
      tmp = alloc(1);
      tmp = xs[i];
      xs[i] = xs[len(xs)-i-1];
      xs[len(xs)-i-1] = tmp;
      i += 1;
      free(tmp);
    }
    free(i);
    free(xs);

it is hopefully easy to see that memory for `xs`, and `i` needs to be allocated, but only once right before the loop, while `tmp` may be allocated every time the loop starts, and deallocated every time the loop ends.
An optimization we could do to this is to move the allocation of `tmp` out of the loop.
This is called "hoisting" it out of the loop.

    xs = alloc(4);
    xs = [4, 3, 0, 7];
    i = alloc(1);
    i = 0;
    tmp = alloc(1);
    while (i*2 < 4)) {
      tmp = xs[i];
      xs[i] = xs[len(xs)-i-1];
      xs[len(xs)-i-1] = tmp;
      i += 1;
    }
    free(tmp);
    free(i);
    free(xs);

With a "functional" style, we would do something like the following

    fun reverse-acc(xs, acc)
      match xs
        [hd, tl..] -> {
          gc(xs); // freed whenever we can?
          new_acc = alloc(1);
          new_acc = [hd, acc..];
          reverse-acc(tl, new_acc)
        }
        []        -> acc
    fun reverse(xs)
      acc = alloc(1);
      acc = [];
      reverse-acc(xs, acc)

it's hard to statically know when that `gc(xs)` can become `free(xs)`, or whether we can fuse the `gc(xs)` with the `alloc(1)` on the next line.
Functional algorithms are easier to do mathematical proofs on generally, because they limit what you need to consider to just what is available inside a function at exactly that moment, while imperative algorithms require you to consider how values may be changing at different times.

Oh well
-------

I intended to write more on Perceus and linear reuse credits, but ran out of time, maybe I'll just read those papers and talk about them later.

[tmp-beans]: 1126-tmp-counting-immutable-beans
[fipfp]: https://www.microsoft.com/en-us/research/publication/fp2-fully-in-place-functional-programming/
[koka]: https://koka-lang.github.io/koka/doc/index.html
[Perceus]: https://www.microsoft.com/en-us/research/publication/perceus-garbage-free-reference-counting-with-reuse/
[hofmann-2006]: https://link.springer.com/content/pdf/10.1007/11693024_3.pdf
