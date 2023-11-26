
ABSTRACT
"reference counting optimized for purely functional programming"
new method for efficiently reclaiming mem used by non-shared vals
reduces stress on global alloc
approach for minimizing # of ref count updates using borrowed refs + heuristic for auto inferring borrow annotations
implemented new compiler for eager+pure fn-al lang w/ multi-threading
experimental results show competitive and often outperforms state-of-art soa


INTRO
ref counting inferior to tracing gc (GHC/ocaml use tracing)
inc/dec refs impacts perf, especially in multi-threaded
cyclic refs leak memory
pause times are deterministic, but often unbounded
"resurrection hypothesis": many objects die right before object of same kind created, eg fn-al updates, list map

series of refinements, starting from lambda-pure
lambda-pure (and Lean) cyclic structs not possible, so ref counts are great
lambda-RC is -pure w/ explicit `inc`/`dec` instrs
owned ref, exactly as many as ref count
borrowed refs do not update count, but are assumed to not outlive source owned ref


EXAMPLES
view ref counts as set of tokens, `inc` creates token, `dec` consumes
fn taking owned ref must consume: `dec` it, move to new heap-alloc val, returning it, or pass to other fn
    id x = ret x
    mkPair x = inc x; let p = Pair x x; ret p
  fst x y = dec y; ret x
`isNil` can have two forms for borrow vs own
    isNil xs = case xs of
      (Nil -> dec xs; ret true)
      (Cons -> dec xs; ret false)
    isNil xs = case xs of (Nil -> ret true) (Cons -> ret false)
matching doesn't introduce binders, have `proj` instead
    hasNone xs = case xs of
      (Nil -> ret false)
      (Cons -> let h = proj_head xs; case h of
        (None -> ret true)
        (Some -> let t = proj_tail xs; let r = hasNone t; ret r))
`reuse`, `reset`, `ctor`
    map f xs = case xs of
      (ret xs)
      (let x = proj_1 xs; inc x; let s = proj_2 xs; inc s;
       let w = reset xs; // if xs is nonshared, reset all refcounts in xs, else alloc box
       let y = f x; let ys = map f s;
       let r = (reuse w in ctor_2 y ys); ret r) // reuse memory (if w = xs, else alloced)
also shows position dependent `ctor`, `proj` and `case` statements
? something about not fusing `reset` and `reuse` but not sure yet
> This example also demonstrates it is not a good idea, in general, to fuse
> reset and reuse into a single instruction: if we removed the let w = reset xs
> instruction and directly used xs in reuse, then when we execute the recursive
> application map f s, the reference counter for s would be greater than 1 even
> if the reference counter for xs was 1. We would have a reference from xs and
> another from s, and memory reuse would not occur in the recursive applications.


PURE IR
    w,x,y,z  in  Var
    c  in  Const
    e  in  Expr     ::=  c y' | pap c y' | x y | ctor_i y' | proj_i x
    F  in  FnBody   ::=  ret x | let x = e; F | case x of F'
    f  in  Fn       ::=  \y'.F
    d  in  Program  ::=  Const -` Fn

all args of function are vars
applied Fn is a const `c`,
partial apply is `pap c y'`, var `x`, or `proj_i x`
fn bodies always end with `ret x`
sequential (non-recursive) `let` statements, and branching with `case`
tail calls are form `let r = c x'; ret r`
program is partial map from const names to impls
body of const may refer back to const, recursion and mutual recursion
use `f x' = F` as sugar for `d(f) = \x'.F`

assume
- ctor appls are fully applied by eta-expand
- no const apps are over-app'd by splitting into 2 apps where necessary
- all var apps take only one arg, by splitting where necessary (currying?)
- every fn abst has been lambda-lifted to a top-level constant `c`
- trivial bindings `let x = y` have been eliminated through copy propaga
- all dead `let` bindings rm'd
- all param and `let` names of a fn are mutually distinct, thus no worry of name capture (or shadowing?)


SYNTAX AND SEMANTICS OF THE REF-COUNTED IR
lambda-RC is ext of lambda-pure
    e  in  Expr  ::= ... | reset x | reuse x in ctor_i y'
    F  in  FnBody  ::= ... | inc x; F | dec x; F
defined l-RC using big-step `r |- <F,s> => <l,s'>` maps `F` and mutable heap `s` under context `r` to location and resulting heap
context `r` maps vars to locations
heap `s` is a map from locations to pairs of (val, ref ct)
val is ctor val or pap'd const
ref ct's of live vals >0, dead vals are removed
    l  in  Loc
    r  in  Ctx  = Var -` Loc
    s  in  Heap  = Loc -` Value x N+
    v  in  Value  ::= ctor_i l' | pap c l'
when app a var, careful to inc pap args when copying out of `pap` cell, and dec cell after
cannot do so w/ explicit ref ct instrs bc # of args in a `pap` is not know statically
dec ref from 1->0 rm's val from heap and recursively decs components
`reset` on ref1 dec's all components, and replaces with `box`, returns loc of cell
this value from `reset` only used by `reuse` or `dec`
`let x = reset y; reuse x...` where y is unique, reuses that memory for new ctor cell, asserting size matches
`let x = reset y; dec x` where y is unique, frees cell, ignoring replaced children
`let x = reset y; reuse x...` where y is shared, stores `box` in `x`, instructs `reuse` to allocate
`let x = reset y; dec x` where y is shared, ?


COMPILER l-pure TO l-RC
1) insert `reset`/`reuse` pairs
2) infer borrowed params
3) insert `inc`/`dec`

the first two steps are performance optimizations, and optional for correctness

    d_reuse : Const -> Fn_RC
    d_reuse c = \y'.R(F)  where  d c = \y'.F

`R` for "reset"
    R : FnBody_pure -> FnBody_RC
    R(let x = e; F) = let x = e; R(F)
    R(ret x) = ret x
    R(case x of F') = case x of (D(x,n_i,R(F_i)))'
        where n_i = #fields of x in i-th branch

`D` for "dead" variable search
    D : Var x N x FnBody_RC -> FnBody_RC
    D(z,n, case x of F') = case x of (D(z,n,F))'
    D(z,n, ret x) = ret x
    D(z,n, let x = e; F) = let x = e; D(z,n,F)
      if  z in e  or  z in F
    D(z,n, F) = let w = reset z; S(w,n,F)
      else, if S(w,n,F) != F  for a fresh w
    D(z,n, F) = F
      else

`S` for "substitution"
    S : Var x N x FnBody_RC -> FnBody_RC
    S(w,n, let x = ctor_i y'; F) = let x = reuse w in ctor_i y'; F
      if |y'| = n
    S(w,n, let x =         e; F) = let x = e; S(w,n,F)
      otherwise
    S(w,n, ret x) = ret x
    S(w,n, case x of F') = case x of (S(w,n,F))'

for each `case` operation, R attempts to insert `reset`/`reuse` instr for var matched by `case` by using `D` in each arm.
`D` takes var `z` to reuse, arity `n` of matched ctor
first location where `z` is dead, ie not used in remaining fn body, and uses `S` to attempt to find+subst a matching constructor `ctor_i y'` instr with a `reuse w in ctor_i y'` in remaining.
if no matching ctor instr can be dfound, `D` does not modify fnbody

    map f xs = case xs of
      (ret xs)
      (let x = proj_1 xs; let s = proj_2 xs;
       let y = f x; let ys = map f s;
       let r = ctor_2 y ys; ret r)

    R(case xs of F') = case xs of (D(xs,n_i,R(F_i)))'
      // nil
      D(xs,0, R(ret xs))
        R(ret xs) = ret xs
      D(xs,0, ret xs) = ret xs
      // cons x xs
      D(xs,2, R(let x = proj_1 xs; F)) =
        R(let x = proj_1 xs; F) = let x = proj_1 xs; R(F)
        R(let s = proj_2 xs; F) = let s = proj_2 xs; R(F)
        R(let y = f x; let ys = map f s; let r = ctor_2 y ys; ret r) =
          let y = f x; let ys = map f s; let r = ctor_2 y ys; R(ret r)
        R(ret r) = ret r
      D(xs,2, let x = proj_1 xs; F) = let x = proj_1 xs; D(xs,2, F)
        if xs in  proj_1 xs  // xs is still live
      D(xs,2, let s = proj_2 xs; F) = let s = proj_2 xs; D(xs,2, F)
        if xs in  proj_2 xs  // xs is still live
      D(xs,2, let y = f x; let ys = map f s; let r = ctor_2 y ys; ret r)
        = let w = reset xs; S(w,2, F)
        if S(w,2, F) != F // need to prove
        S(w,2, let y = f x; let ys = map f s; F)
          = let y = f x; let ys = map f s; S(w,2,F)
        S(w,2, let r = ctor_2 y ys; F)
          = let r = reuse w in ctor_2 y ys; F
          if |y ys| = 2
      D(x,2, let x = proj_1 xs; F)
        = let x = proj_1 xs; let s = proj_2 xs;
          let w = reset xs;
          let y = f x; let ys = map f s;
          let r = reuse w in ctor_2 y ys;
          ret r
    R(case xs of F') = case xs of
      (ret xs)
      (let x = proj_1 xs; let s = proj_2 xs;
       let w = reset xs;
       let y = f x; let ys = map f s;
       let r = reuse w in ctor_2 y ys;
       ret r)

sort of scans in two phases, first is R+D phase finding place to insert `reset`, then S phase searches after that for a place to put `reuse`

inferring borrow sigs
infer map ```b: Const -` {O,B}*```, which for every fn should return list mapping params to Owned or Borrowed
borrow annotations can be provided manually, but inferring is nice
if fn f takes param x as Bref, then x may be shared at runtime
cannot use borrowed x in `reset x`, even if rc is 1
assume each b(c) has some length as param list in d(c)
cannot statically assert that pap with bref value will not esacpe
extend d_reuse to program d_b w wrapper constant c_O := c (assum name is fresh) for any const c, set b(c_O) := O', and replace any occur of `pap c y'` with `pap c_O y'`


    collect_O : FnBody_RC -> 2^Vars
    collect_O(let z = ctor_i x'; F)  = collect_O(F)
    collect_O(let z = reset x; F)    = collect_O(F) + {x}
    collect_O(let z = reuse x in ctor_i x'; F) = collect_O(F)
    collect_O(let z = c x'; F) = collect_O(F) + {x_i in x' | b(c)_i = O}
    collect_O(let z = x y; F)        = collect_O(F) + {x,y}
    collect_O(let z = pap c_O x'; F) = collect_O(F) + {x'}
    collect_O(let z = proj_i x; F)   = collect_O(F) + {x}
      if z in collect_O(F)
    collect_O(let z = proj_i x; F)   = collect_O(F)
      if z nin collect_O(F)
    collect_O(ret x) = {}
    collect_O(case x of F')       = union(F_i in F, collect_O(F_0))

insert rc ops
given wf b and d_b, give
    d_RC(c): Const -> Fn_RC
    d_RC(c) = \y'.O-(y', C(F,b_l))
      where d_b(c) = \y'.F,
            b_l = [y' |-> b(c), ... |-> O]

map `b_l: Var->{O,B}` tracks borrow status of local vars, default is O
inc ref before use in owned ctx, dec after last use
`O+_x` prepares x for use in owned ctx w/ inc
    O+_x(V,F,b_l) = F         if  b_l(x) = O  &  x nin V
    O+_x(V,F,b_l) = inc x; F  else
`O-_x` decs x if own+dead
    O-_x(F,b_l) = dec x; F  if  b_l(x) = O  &  x nin FV(F)
    O-_x(F,b_l) = F         else
    O-([x0,x'],F,b_l) = O-(x', O-_x0(F,b_l), b_l)
    O-([],     F,b_l) = F

    C: FnBody_RC x (Var -> {O,B}) -> FnBody_RC
    C(ret x, b_l) = O+_x({}, ret x, b_l)
    C(case x of F', b_l) = case x of (O-(y',C(F,b_l),b_l))'
      where {y'} = FV(case x of F')
    C(let y = proj_i x; F, b_l) 
      = let y = proj_i x; inc y; O-_x(C(F,b_l), b_l)
      if b_l(x) = O
    C(let y = proj_i x; F, b_l)
      = let y = proj_i x; C(F,b_l[y|->B])
      if b_l(x) = B
    C(let y = reset x; F, b_l) = let y = reset x; C(F,b_l)
    C(let z = c y'; F, b_l)
      = C_app(y', b(c), let z = c y'; C(F, b_l), b_l)
    C(let z = pap c y'; F, b_l)
      = C_app(y',b(c), let z = pap c y'; C(F, b_l), b_l)
    C(let z = x y; F, b_l)
      = C_app(x y, O O, let z = x y; C(F, b_l), b_l)
    C(let z = ctor_i y'; F, b_l) 
      = C_app(y', O', let z = ctor_i y', C(F,b_l), b_l)
    C(let z = reuse x in ctor_i y'; F, b_l)
      = C_app(y', O', let z = reuse x in ctor_i y'; C(F,b_l), b_l)

    C_app: Var* x {O,B}* x FnBody_RC x (Var -> {O,B}) -> FnBody_RC
    C_app(y y', O b', let z = e; F, b_l)
      = O+_y(y'+FV(F), C_app(y',b',let z = e; F,b_l), b_l)
    C_app(y y', B b', let z = e; F, b_l)
      = C_app(y',b', let z = e; O-_y(F,b_l), b_l)
    C_app([], _, let z = e; F, b_l) = let z = e; F



Today, I'll be reviewing a paper from 2020 called "Counting Immutable Beans" by Sebastian Ullrich and Leonardo de Moura.
The authors present an automated memory management system based on reference counting,
which uses static analyses to both infer RC operations and reduce system allocator usage.
This paper not only describes a theory, but contains some benchmarking results of their system vs similar systems in use,
and since these guys are the some ones that work on the Lean programming language, this system was a basis for their rewrite of Lean from version 3 to 4.

The first thing you need to know when reading this is that there are 2 common approaches to automated memory management: reference counting, and garbage collection.
There is a tradeoff where reference counting has more runtime overhead, but has predictable runtime performance and simpler implementation,
while garbage collection is more complex to implement, but gives more room for runtime performance optimization.
That's my summarization but of course there's a bunch of asterisks and people writing papers to show that that's not quite true, this paper being one of them.
The authors argue in this paper that reference counting approach can be made performant with two techniques implemented as static program transformations.

Their approach takes a pure functional language with no concept of memory management (named `lambda_pure` in the paper), and maps to the same language with added operations on RC'd variables (named `lambda_RC`).
They introduce two operations `reset`/`reuse` for reusing memory without invoking the system allocator to free/alloc new memory, which is their main trick for improving performance, and what they spend the first half of the paper describing.
There is an assumption here that invoking the system allocator imposes the majority of runtime performance overhead, which seems reasonable to me.

In order to reuse existing allocated memory, you need to make sure no one else is using that memory, and that it is the right size.
The `reset x` operation checks at runtime whether `x`'s reference count is 1, in which case , if `x` isn't used anymore, `x`'s memory can be reused for something of the same size instead of being `free`'d.
The analysis to determine "isn't being used anymore" is named `D` in the paper (for "Dead", as a variable that will be used later is considered "live"),
and the analysis for "later something of the same size needs memory" is named `S` (for "substition").
The paper assumes that "number of arguments to constructor" is sufficient for measuring whether memory existing can be reused, and in any language where primitive values are all the same size this is true.
I'm used to languages like C or Rust, where primitive values all have different memory sizes, so this sounds foreign to me, but as I understand many languages, especially functional or scripting languages have no problem representing all values as some multiple of machine words, and any bit-packing is seen as totally optional optimization.

That's a high-level description of the general approach, but these `reset`/`reuse` operations could be stuck anywhere we use a variable.
So now we have two extremes of "no memory reuse", or "trying to reuse everything", both of which (likely?) have poor performance.
This paper describes heuristics for adding checks to hopefully gain the benefit of reusing memory without the downsides of a million runtime checks.
They call it the "resurrection hypothesis" in the paper, and I understand it as:
when you want to construct a value, there's usually a deconstructed value of the same size right before.
This heuristic is then to add a `reset` check on deconstructed values, and then search forward for a constructor statement to insert a `reuse`.

The automatic reuse of memory is the technique that is more novel to me, but the second technique is one I'm very familiar with: borrowing vs owning values.
The idea is that if a value is a parameter of a function, and does not escape that function call, then there is no need to `inc` the refcount before calling just to `dec` the refcount inside the function.
Users of Swift or Rust may recognize this technique.
Rust has a more complicated task of managing mutability, which a pure functional language doesn't have, and values escaping up the stack without being easily cloned (this necessitates all the lifetime annotations that users absolutely love /s) which this language also doesn't have a problem with because refcounted values can just increase the refcount.
The paper describes an algorithm for inferring borrowed vs owned parameters.
Interestingly, the language does not permit constructing general closures, instead allowing partial application of functions which makes the algorithm simpler but I don't think restricts expressibility.
(it feels like returning a closure can be rewritten as a global function that accepts all closed variables as parameters, and returning a partial application of that function, but I'm not 100% certain)

One of the ideas that popped into my head is maybe implementing a Rust DSL which translates normal looking Rust syntax to a form where all function params are `Rc<_>`'d and the algorithms for this languages' `case` and `ctor_i` are translated to enum `match` and construction.
I'm not sure if the memory reuse checks are sufficient (as noted above, it's not generally true that the size of some constructed value is just `n` times the number of fields), but maybe something could be figured out.
I've read in Rust zulip threads and some dev blogs that it would be nice to have a way to
opt into some Rust syntax which doesn't require as much annotation to manage memory, and maybe this could help?
I enjoyed the read, and I'd recommend it to anyone thinking of implementing a pure functional language to think of ref-counted memory management and take a read themselves.

