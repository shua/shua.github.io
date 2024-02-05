<pmeta id="created">2024-02-04</pmeta>
<pmeta id="title">TMP: Abstraction-Safe Effect Handlers via Tunneling (pt 2)</pmeta>

[Last time][tmp-tunnel-1] I reviewed [_"Abstraction-Safe Effect Handlers via Tunnelling"_][tunneling], I got stuck trying to mentally translate the authors' nice surface syntax which they used for examples, into the more strict and verbose syntax they used for the actual definitions and proofs.
I'm going to start right back off there, and hopefully also get into the proofs section of the paper as well before closing out this TMP post.


## Syntax

The example I finished  with last time was the following,
```
val g = fun(x: int) : bool / Yield[int] { yield(x); f(x) }
try { fsize(tr, g) }
with yield(x: int) void { ... }
```

which translated into their well-defined syntax would be more like

```
let g: Pi hh:Yield[int] [int -> bool]_hh 
     = \hh:Yield[int].\x:int.
       let _: void = UP hh x in
       f x
in
DN^l _ (\hh:Yield[int]. fsize(tr, g[hh])) 
         (handler^Yield[int] x k. ...)^l
```

This seems simple enough, but their motivating example was two different implementations of `fsize` that break the abstraction of functions.
Their argument in the paper is that this syntax and rules allow them to write the same code, but it preserves abstraction.
This was tricky to prove, because the code they give as an example is written in their surface syntax, and uses some things that are not easy to translate still.
It doesn't invalidate their point, as "hard" isn't "impossible", but it does have a very "proof of this is left as an exercise for the reader" feel, which is unfortunate, as it really seems they wanted to help the reader along, even going so far as to spell out a bunch of other things explicitly in second "technical report" publication.

The two troublesome functions are as follows in the surface syntax:

```
fsize1[X,E](tr: Tree[X], f: X->bool/E): int/E {
  val num = 0
  try { fiterate(tr, f) }
  with yield(x: X): void {
    ++num; resume()
  }
  return num
}

fsize2[X,E](tr: Tree[X], f: X->bool/E): int/E {
  val lsize = fsize2(tr.left(), f)
  val rsize = fsize2(tr.right(), f)
  val cur = f(tr.value()) ? 1 : 0
  return lsize + rsize + cur
}
```

where `fiterate` has signature
```
fiterate[X,E](tr: Tree[X], f: X --> bool/E): void/Yield[X],E
```

This is the motivating example, that since these two functions `fsize1` and `fsize2` have the same signature, and logically do the same thing, you should be able to choose either one and get the same answer.

Frustratingly, mutating variables and if/then statements, for example `++num` and `_ ? _ : _`, are all more complicated features than what is available to us in the core syntax they define.
I think if/then and booleans can be modeled in simply-typed lambda calculus (STLC), but I'm not sure how to model mutable state without either passing implicit variables through everything or [extending STLC to support it][STLC-mut].
Why is this frustrating? Because the authors' point that their core language could express something like `fsize1` and `fsize2` while also solving the issues presented with other systems is left as a couple <strike>leaps of faith</strike> exercises on the part of this poorly-educated reader for which each step is not so obvious.

Nonetheless, I can _accept_ that some proofs on the core language can be adapted to match a more complicated language, and that the contribution this paper makes to understanding type and effects systems is appreciated.

## Proofs

I'd like to move on from that part that I don't totally understand, to the next part on proofs which I only very partially understand.
What they aim to prove is called "contextual equivalence" between two terms.
The final proof takes the form
```
D|P|G|I |- t1 ~ctx t2 : [T]_e
```
which suggests either a proof through transitivity (ie finding a third thing `t3` such that `t1 ~ctx t3` and `t2 ~ctx t3`), a proof of both sides (assuming there's some weaker relation `<ctx` such that `t1 <ctx t2` and `t2 <ctx t1` implies `t1 ~ctx t2`) or some proof by contradiction.
This paper _defines_ contextual equivalence `~ctx` as `t1 <ctx t2` and `t2 <ctx t1` and then defines `t1 <ctx t2` as "contextual refinement"
```
D|P|G|I |- t1 <ctx t2 : [T]_e == All C. |- C:D|P|G|I|[T]_e ~> T' =>
                                 (Exs v1. C[t1] -->* v1) => (Exs v2. C[t2] -->* v2)
```

In more words, this says that term `t1` is a refinement of `t2` (under context `D|P|G|I` with type `[T]_e`) if, for all programs-with-a-hole `C` (where `C` is well-formed) such that `C` with the hole filled with `t1` eventually evaluates to a value, then `C` with `t2` also eventually evaluates to a value.
This is a neat trick, because, as the authors note, it is enough to prove that termination of one program implies termination of the other, and you do _not_ need to make it part of the proof that `v1 == v2`.
Why is that? Because it is a proof of _all_ programs-with-a-hole `C`, that includes programs that only terminate if the hole evaluates to `v1`, maybe something that looks like
```
while _ != v1 {}
```

Then `Exs v1. C[t1] -->* v1` and it must be true that `Exs v2. C[t2] -->* v2`, which in this case is only when `v2 == v1`.

That's actually the easy part, that I sort of understand.
The next section goes on to introduce a proof tactic called "step-indexing" because normal induction wasn't strong enough to handle recursively defined effects.
They also define between 8 and 10 other logical relations, and finally the relations `~log` and `<log` which are "logical equivalence" and "logical refinement" respectively, and show that logical refinement implies contextual refinement.

Their last section provides a walkthrough I was waiting for, of proving two programs as being contextually equivalent.
They give the terms in the core language (with some extensions for defining numbers and addition), and the equivalent terms in the surface syntax, and then 2 and a half pages of proof for their equivalence.

## Conclusion

I really enjoyed reading this paper and trying to implement the ideas in it, as evidenced by the fact that I gave it two parts in what is supposed to be a 1-paper-a-week series.
It touches on a lot of parts of programming language design and proofs, from ambiguous evaluation, syntax, operational semantics and typechecking, to logical semantics and Coq proofs (oh yeah, they have an addendum with their proofs done via Coq proof assistant).
It makes me want to extend their core language, and try writing in my own practical language with tunneled effects.

If you've got any suggestions for other papers you think I should read and might enjoy working through, please email me.


[tmp-tunnel-1]: /2024/0115-tmp-tunneling-1.html
[tunneling]: https://ecommons.cornell.edu/items/988aacdc-a8b5-487e-8cfe-166623f390e5
[STLC-mut]: https://www.cs.cornell.edu/courses/cs4160/2020sp/sf/plf/full/References.html
