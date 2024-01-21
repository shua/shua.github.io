<pmeta id="created">2024-01-21</pmeta>
<pmeta id="title">Substitution: the boring part of eval implementations</pmeta>

This week, instead of implementing some type theory paper, I decided to automate some tedious programming.
Specifically, many language grammars, at least anything that includes variables and evaluation, uses a concept called "substitution", which is commonly denoted in papers as `e{v/x}` or `e[x:=v]`.
What this means is to take the expression `e` and replace any occurrances of variable `x` with value `v`.

> It's not quite as simple as _any_, because, for instance, `(\y \y y) 1` should that be `\y 1` or `\y y`?
> So there are some cases where you don't replace the variable, for instance inside a function body which has an argument variable that is spelled the same.

With some exceptions, substitution is a fairly mechanical and uninteresting transformation, but a necessary one.
This week, I wrote some code which will write the substitution logic for grammars and languages that I've been implementing.

## Motivating example

Let's start with a fairly simple lambda calculus like language, with expression `e` values `v` and substitution `e[x:=v]`:

```
e ::= v | x | e e
v ::= () | \x.e

"e[x:=v]"
() [x:=v]     = ()
\y.e [x:=v]   = \y.(e[x:=v])  if x != y
                \y.e          if x == y
e1 e2 [x:=v]  = (e[x:=v]) (e2[x:=v])
y[x:=v]       = v             if x == y
                y             if x != y
```

in rust, I have been writing something like the following

```
enum E { V(V), X(usize), App(Box<E>, Box<E>) }
enum V { Unit, Fn(Box<E>) }

fn subst_e(e: &mut E, x: usize, v: V) {
  match e {
    V(w) => subst_v(w, x, v),
    X(y) if *y == x => *e = E::V(v),
    X(_) => {}
    App(e1, e2) => {
      subst_e(e1, x, v.clone());
      subst_e(e2, x, v);
    }
  }
}

fn subst_v(v: &mut V, x: usize, v: V) {
  match v {
    Unit => {}
    Fn(e) => subst_e(e, x+1, v),
  }
}
```

notably, instead of encoding variables as `String`, they are encoded as DeBruijn indices, or roughly "how far up in the ast do we have to go to find the function that binds this variable?".
So something like `\y \x x` would be encoded as 
```
E::V(V::Fn(Box::new(E::V(V::Fn(Box::new(E::X(1)))))))
```
(verbose, I know) or sometimes written like `\_ \_ 0`, while `\y \x y` would be `\_\_1`.
This encoding of variables is useful for language implementations, but I'm not going to dig into it too much here.

Anyway, that is simple enough, just two functions, but it started getting a bit much when I started implementing more languages with multiple different kinds of variables.
For instance, a polymorphic lambda calculus includes both value `e[x:=v]` and type substitution `e[a:=s]`.

```
e ::= v | x | e e | e [s]
v ::= () | \x:s.e | /\a.e
s ::= () | a | s -> s | all a.s

"e[x:=v]"
...

"e[a:=s]"
...
(e [s2])[a:=s] = (e[a:=s]) [(s2[a:=s])]
(/\b.e)[a:=s]  = /\b.(e[a:=s])  if b != a
                 /\b.e          if b == a
(\x:s1.e)[a:=s] = \x:(s1[a:=s]).(e[a:=s])

"s[a:=s]"
b[a:=s]          = s  if b == a
                   b  if b != a
(all b.s1)[a:=s] = all b.(s[a:=s])  if b != a
                   all b.s          if b == a
```

which translates to similar rust code
```
enum E { V(V), X(usize), App(Box<E>, Box<E>), TApp(Box<E>, S) }
enum V { Unit, Fn(S, Box<E>), TFn(Box<E>) }
enum S { Unit, Fn(Box<S>, Box<S>), TFn(Box<S>) }

fn subst_e(e: &mut E, x: usize, v: V) { /* 4 cases */ }
fn subst_v(v: &mut V, x: usize, w: V) { /* 3 cases */ }
fn tsubst_e(e: &mut E, x: usize, t: S) {
  match e {
    /* 3 other cases */
    TApp(e, s) => {
      tsubst_e(e, x, t.clone());
      tsubst_s(s, x, t);
    }
  }
}
fn tsubst_v(v: &mut V, x: usize, t: S) { /* pretty much the same 3 cases */ }
fn tsubst_s(s: &mut S, x: usize, t: S) { /* etc */ }
```

I thought I would write out all the cases, but I got tired, and that brings me to this week.
I've been writing out all these functions, but for every new kind of substitution `X`, I need to implement it for `Y` different enums, and it's all pretty much the same where you simply forward the substitution into the sub-expressions.
I'm not alone in thinking this is tedious, most language papers I read don't even write out what `e[x:=v]` means, they sometimes explicitly say it's substitution, but they almost never define all the cases.

## My solution

I started out by defining two traits:
```
trait SubstAny<T> {
  fn subst_any(&mut self, x: usize, v: T);
}
trait Subst<T>: SubstAny<T> {
  fn subst(&mut self, x: usize, v: T) { self.subst_any(x, v) }
}
```

Why two?
Well, `SubstAny` is for the general case, where the logic is just "perform substitution on any sub-terms" eg `(e1 e2)[x:=v] = (e1[x:=v]) (e2[x:=v])`,
and `Subst` is for implementing specific overrides, like `x[x:=v] = v`.

```
impl<T> SubstAny<T> for E 
where
  T: Clone,
  E: Subst<T>,
  V: Subst<T>,
  S: Subst<T>,
{
  fn subst_any(&mut self, x: usize, v: T) {
    match self {
      V(w) => w.subst(x, v),
      X(_) => {} // generally, do nothing
      App(e1, e2) => {
        e1.subst(x, v.clone());
        e2.subst(x, v);
      }
      TApp(e, s) => {
        e.subst(x, v.clone());
        s.subst(x, v);
      }
    }
  }
}
impl<T> SubstAny<T> for V
where
  T: Clone,
  E: Subst<T>,
  S: Subst<T>,
{
  fn subst_any(&mut self, x: usize, v: T) {
    match self {
      Unit => {}
      Fn(s, e) => {
        s.subst(x, v.clone());
        e.subst(x+1, v);
      }
      TFn(e) => e.subst(X+1, v),
    }
  }
}
impl<T> SubstAny<T> for S
wehre
  T: Clone,
  S: Subst<T>,
{
  fn subst_any(&mut self, x: usize, v: T) {
    match self {
      Unit => {}
      A(_) => {}
      Fn(s1, s2) => {
        s1.subst(x, v.clone());
        s2.subst(x, v);
      }
      TFn(s) => s.subst(x+1, v),
    }
  }
}

impl Subst<V> for E {
  fn subst(&mut self, x: usize, v: V) {
    match self {
      X(y) if *y == x => *self = E::V(v),
      e => e.subst_any(x, v),
    }
  }
}
impl Subst<S> for E {} // default impl is just subst_any
impl Subst<V> for V {}
impl Subst<S> for V {}
impl Subst<V> for S {
  // only because this specific grammar does not allow values to be sub-terms of types
  // so we can skip the default subst_any logic and do nothing instead
  fn subst(&mut self, x: usize, v: V) {}
}
impl Subst<S> for S {
  fn subst(&mut self, x: usize, v: S) {
    match self {
      A(a) if *a == x => *self = S,
      s => s.subst_any(x, v),
    }
  }
}
```

it's a way to remove all the duplicated logic across substituting different kinds of variables (eg type `a` and expr variables `x`).
That works fine, but there still feels like a little duplication in that, the simple case of `SubstAny` just visits (almost) every field of every variant of the enum and calls `_.subst(x, v)`.
Surely even this could be automatically derived?

## Procedural macros

This is the first time I've written a rust procedural macro.
My first attempt was to see how far I could get with just the provided compiler `proc_macro` package.
The answer is: not very far.
I'd have to write my own parser for rust enums and structs given only a stream of `TokenTree`s.
In other words, `TokenTree`s can be one of [4 things][TokenTree]: an ident (`pub`, `x`, `proc_macro` all count), punctuation (eg `,`, `::`, etc), a group (eg `{_}`, `(_)`), and literals (eg `1`, `hello`).
I thought 

> I'll just check for `enum` then the name I guess, like `E`
> ...
> oh wait but what if it has generic arguments like `E<T>` 
> does that count as a group after or punctuation+ident+punctuation?
> ...
> oh darn, visibility like `pub` or `pub(crate)` is also optional
> ...
> can an enum be `const`?

It ended up being too much parsing code that I wasn't even sure about to get past the name of the enum, forget about the variants and fields.
Though, maybe if I did it again, I could consult the official reference [enum grammar].

Fortunately, some great libraries for parsing and generating rust code exist, and they already have great interop with existing `proc_macro` package: [`syn`], [`quote`], and [`proc_macro2`].
Working with `proc_macro` is a bit of a headache, because you can't use that package outside of procedural macros, specifically you can't really run tests on the function you define.
That's why using those helper crates instead are nice, and the derive macro can look like the following:

```
extern crate proc_macro;
use proc_macro::TokenStream;

#[proc_macro_derive(SubstAny)]
fn subst_any_proc_macro(input: TokenStream) -> TokenStream {
  // put the least code you possibly can here, because you cannot test this in a #[test] fn
  inner::subst_any_proc_macro(input.into()).into()
}

mod inner {
  use proc_macro2::TokenStream;
  use quote::quote; // nice quote! macro

  fn subst_any_proc_macro(input: TokenStream) -> TokenStream {
    let derive_target = match syn::parse2::<syn::DeriveInput>(input) {
      Ok(q) => q,
      Err(err) => {
        // we print a compiler_error! into the source so it errors there instead of inside the proc_macro
        // you could also match 
        return quote!(compiler_error!("{}", stringify!(#err)));
      }
    };
    let mut tokens = TokenStream::new();
    // do the rest of the parsing etc, and generate something
    quote!{
      impl #impl_params SubstAny<T> for #name #ty_params #where_clause {
        fn subst_any(&mut self, x: usize, v: T) {
          #body
        }
      }
    }
  }

  #[test]
  fn test_proc_macro() {
    let input = quote!( enum E { A, B, C } );
    // yay normal tests
    assert_eq!(subst_any_proc_macro(input), quote!(impl<T> SubstAny<T> for E { ... });
  }
}
```

anyway, I auto-derive the `SubstAny<T>` implementation for enums and structs now and I learned how to make a proc-macro.

```
#[derive(SubstAny)]
enum E { V(V), X(#[subst_skip] usize), App(Box<E>, Box<E>), TApp(Box<E>, S) }
#[derive(SubstAny)]
enum V { Unit, Fn(S, #[subst_bind] Box<E>), TFn(#[subst_bind] Box<E>) }
#[derive(SubstAny)]
enum S { Unit, A(#[subst_off] usize), Fn(Box<S>, Box<S>), TFn(#[subst_bind] Box<S>) }

impl<T> Subst<T> for V
where T: Clone,
  S: Subst<T>,
  E: Subst<T> {} // just use default subst_any
impl Subst<V> for E {
  fn subst(&mut self, x: usize, v: V) {
    match self { X(y) if *y == x => *self = E::V(v), e => e.subst_any(x, v), }
  }
}
impl Subst<S> for E {}
impl Subst<V> for S { fn subst(&mut self, x: usize, v: V) {} }
impl Subst<S> for S {
  fn subst(&mut self, x: usize, v: S) {
    match self {
      A(a) if *a == x => *self = v,
      s => s.subst_any(x, v),
    }
  }
}
```

if you want to see how this looks for my implementation of [last week's paper][tmp-efftunnel] check out [eff_tunnel.rs].

## What could be better, some possible next steps

There are some cases where the auto-generated `SubstAny<T>` may not be as efficient with memory as a hand-rolled implementation for every kind of grammar term substituting every other kind of grammar term, but I haven't had any issues and it helps me not get bogged down in the tedium of writing these substitute implementations.
The other thing that could be better is writing some macros that construct expressions, because it's very verbose to write `E::App(Box::new(e1), Box::new(E::V(v)))` when I _mean_ `e v`.

I usually create some set of macros because I don't want to write a string parser, something like:
```
macro_rules! expr {
  (fn($x:ident : $s:tt) $($e:tt)*) => { E::V(V::Fn(typ!($s), Box::new({ let $x = _; expr!($($e)*) }))) };
  ... all other forms ...
}

let e = expr!(fn(x: ()) x);
```

but those rules also end up being _pretty_ similar to the enum declaration, and I make them every time I create a grammar for a language, so I wonder if I could generate them with a proc-macro as well?

[TokenTree]: https://github.com/rust-lang/rust/blob/master/library/proc_macro/src/lib.rs#L651
[`syn`]: https://github.com/dtolnay/syn
[`quote`]: https://github.com/dtolnay/quote
[`proc_macro2`]: https://github.com/dtolnay/proc-macro2
[enum grammar]: https://doc.rust-lang.org/stable/reference/items/enumerations.html
[tmp-efftunnel]: ../2024/0115-tmp-tunneling-1.html
[eff_tunnel.rs]: https://github.com/shua/lang-noodles/blob/main/src/bin/eff_tunnel.rs
