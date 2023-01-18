<pmeta id="created">2020-01-15</pmeta>
<pmeta id="title">RiiR: Ghosts of Departed Proofs</pmeta>

This is the first in hopefully a series of posts where I try rewriting something in [Rust].

## The inspiration
Read an interesting paper called [Ghosts of Departed Proofs][GDP] about using the type
system in haskell to ensure certain properties are met when using a library,
without using any extra computation or space at runtime.

The example given is to make sure that users of a merging and sorting library
don't mess up the calls into the library.
When they call

	x = sort_by(comp, list1)
	y = sort_by(comp, list2)
	z = merge_by(comp, x, y)

`comp` here is some comparison function that must be the same. Thus

	x = sort_by(comp, list1)
	y = sort_by(other_comp, list2)
	z = merge_by(comp, x, y)

will be undefined, though the likely result is that `z` is not sorted.

The paper proposes a way of naming the `comp` function, but we only want that "name"
to exist at compile-time, and to not affect runtime at all.

Haskell has a concept of ["phantom types"][phantom_types] which are types that
end up with no runtime representation, which this paper uses, along with GHC haskell's
[`Coercible`], to generate unique types for every "name", so that attempts to use
one named object in place of another will result in a compiler error.
Since the "name" is a phantom type variable, it will result in no runtime overhead.

## The result

I decided to try implementing [GDP] in [Rust].
First thing we need is a way of attaching types to other types without attaching data.
Rust has [`PhantomData`] for that, which is similar enough for my use.

One of the issues I ran into early on, was trying to just rewrite the functions from the paper

	struct Named<Name, A>(A, PhantomData<Name>);
	fn named<Name, A, T, K: Fn(Named<A, Name>) -> T>(x: A, k: K) -> T {
		k(Named(x, PhantomData))
	}


resulted in the compiler not knowing what type to give `Name`, and it wanted _me_ to specify.
Well I don't know what type to give it.
Thinking about it, I reworded the issue as: I need a unique type to be created for every call to name.

### You're going to make *me* do this?

After wording it this way, I remembered something I'd read and run into when trying to use closures in Rust.

	fn run_fn(f: Fn(i64) -> i64, x: i64) -> i64 {
		f(x)
	}

	fn main() {
		run_fn(|x| x*2, 2)
	}

will get compiler errors,

	warning: trait objects without an explicit `dyn` are deprecated
	 --> src/main.rs:1:14
	  |
	1 | fn run_it(f: Fn(i64) -> i64, x: i64) -> i64 {
	  |              ^^^^^^^^^^^^^^ help: use `dyn`: `dyn Fn(i64) -> i64`
	  |
	  = note: `#[warn(bare_trait_objects)]` on by default

	error[E0277]: the size for values of type `(dyn std::ops::Fn(i64) -> i64 + 'static)` cannot be known at compilation time
	 --> src/main.rs:1:11
	  |
	1 | fn run_it(f: Fn(i64) -> i64, x: i64) -> i64 {
	  |           ^ doesn't have a size known at compile-time
	  |
	  = help: the trait `std::marker::Sized` is not implemented for `(dyn std::ops::Fn(i64) -> i64 + 'static)`
	  = note: to learn more, visit <https://doc.rust-lang.org/book/ch19-04-advanced-types.html#dynamically-sized-types-and-the-sized-trait>
	  = note: all local variables must have a statically known size
	  = help: unsized locals are gated as an unstable feature

	error[E0308]: mismatched types
	 --> src/main.rs:6:12
	  |
	6 |     run_it(|x| x*2, 2)
	  |            ^^^^^^^ expected trait std::ops::Fn, found closure
	  |
	  = note: expected type `(dyn std::ops::Fn(i64) -> i64 + 'static)`
	             found type `[closure@src/main.rs:6:12: 6:19]`

1. `Fn(i64) -> i64` is a _trait_ not a type, so old behaviour is for the compiler to look at that and say "f will be an object with _some type that implements Fn..._"
   if I want that, I should specify by adding `dyn` before the trait
2. even with the `dyn` behaviour, it complains that the type is not known statically at compile time.
   You need this in rust, because the way the compiler is working for pass-by-value
   ```
   add f to stack
   add x to stack
   call run_it
   ```

   if the compiler doesn't know how big `f` is going to be, it can't make the `add f to stack` commands

   Usually, for `dyn` arguments, you want to pass-by-reference, so either `&dyn Fn(_) -> _` or `Box<dyn Fn(_) -> _>`
3. there is an alternative to `dyn` which is `impl` types, and writing
   ```
   fn run_it(f: impl Fn(i64) -> i64, x: i64) -> i64
   ```
   is like writing
   ```
   fn run_it<F: Fn(i64) -> i64>(f: F, x: i64) -> i64
   ```

   This is known as "static dispatch" and the result is similar to C++ templates.
   It is also saying "`f` is of _some type that implements Fn..._", but instead of telling the compiler
   to add type information alongside the data at runtime (like `dyn`), it tells the compiler to create
   a version of `run_it` for every type that is passed in for `f` in this program.

lastly, that line

	  = note: expected type `(dyn std::ops::Fn(i64) -> i64 + 'static)`
	             found type `[closure@src/main.rs:6:12: 6:19]`

is what interests me.
`[closure@src/main.rs:6:12: 6:19]` is not a type that I can specify in source, that is generated by the compiler.
In rust, no matter how similar two closures are, if they are defined in two separate lines of source, they get two unique and non-overlapping types.

To demonstrate this, we can look at return types.
A function must only return _one_ type, so

	fn no_bueno(b: bool) -> impl F {
		if b {
			||{}
		} else {
			||{}
		}
	}

results in

	error[E0308]: if and else have incompatible types
	 --> src/lib.rs:5:9
	  |
	2 | /     if b {
	3 | |         ||{}
	  | |         ---- expected because of this
	4 | |     } else {
	5 | |         ||{}
	  | |         ^^^^ expected closure, found a different closure
	6 | |     }
	  | |_____- if and else have incompatible types
	  |
	  = note: expected type `[closure@src/lib.rs:3:9: 3:13]`
	             found type `[closure@src/lib.rs:5:9: 5:13]`
	  = note: no two closures, even if identical, have the same type
	  = help: consider boxing your closure and/or using it as a trait object

I can use closure types as my type for `Name` in the `named` function, then
the compiler will generate a unique type for me at compile time.

### Complete example

	mod named {
	    use core::marker::PhantomData;

	    #[derive(Clone)]
	    pub struct Named<Name, A>(pub A, PhantomData<Name>);

	    // don't use this, use the macro name!
	    pub fn name<Name: Fn(), T, A, K: Fn(Named<Name, A>) -> T>(_: Name, x: A, k: K) -> T {
	        k(Named(x, PhantomData))
	    }
	    
	    #[macro_export]
	    macro_rules! name {
	        ($x:expr, $k:expr) => {
	            // (ab)using rustc's implementation of closure types
	            // the compiler generates a unique type for every closure
	            // thus if we pass a new closure every time, then Name is given a unique type every time as well
	            // here "||{}" is a closure that takes no arguments and does nothing
	            $crate::named::name(||{}, $x, $k)
	        }
	    }
	}
	
	mod listutils {
	    use core::cmp::Ordering;
	    pub fn merge_by<A, Comp: Fn(&A, &A) -> Ordering>(comp: Comp, mut xs: Vec<A>, mut ys: Vec<A>) -> Vec<A> {
	        if xs.is_empty() { return ys; }
	        if ys.is_empty() { return xs; }
	        match comp(&xs[xs.len() - 1], &ys[ys.len() - 1]) {
	            Ordering::Greater => {
	                let x = xs.pop().unwrap();
	                let mut ret = merge_by(comp, xs, ys);
	                ret.push(x);
	                ret
	            },
	            _ => {
	                let y = ys.pop().unwrap();
	                let mut ret = merge_by(comp, xs, ys);
	                ret.push(y);
	                ret
	            }
	        }
	    }
	    
	    pub fn greater_than<A: Ord>(x: &A, y: &A) -> Ordering {
	        x.cmp(y)
	    }
	}
	
	mod sorted {
	    use super::named::Named;
	    use super::listutils as U;
	    use core::marker::PhantomData;
	    use core::cmp::Ordering;
	    
	    #[derive(Clone)]
	    pub struct SortedBy<Comp, A>(pub A, PhantomData<Comp>);
	    
	    pub fn sort_by<Comp, A, CompFn: Fn(&A, &A) -> Ordering>(comp: Named<Comp, CompFn>, mut xs: Vec<A>) -> SortedBy<Comp, Vec<A>> {
	        SortedBy({ xs.sort_unstable_by(comp.0); xs }, PhantomData)
	    }
	    
	    pub fn merge_by<Comp, A, CompFn: Fn(&A, &A) -> Ordering>(comp: Named<Comp, CompFn>, xs: SortedBy<Comp, Vec<A>>, ys: SortedBy<Comp, Vec<A>>) -> SortedBy<Comp, Vec<A>> {
	        SortedBy(U::merge_by(comp.0, xs.0, ys.0), PhantomData)
	    }
	}
	
	use sorted::*;
	use listutils::greater_than;
	
	fn main() {
	    name!(greater_than, |gt| {
	        let xs = sort_by(gt.clone(), vec![6, 2, 4]);
	        let ys = sort_by(gt.clone(), vec![5, 1, 4]);
	        println!("{:?}", merge_by(gt, xs, ys).0);
	    });
	    
	    fn less_than<A: Ord>(x: &A, y: &A) -> core::cmp::Ordering { greater_than(x, y).reverse() }
	    name!(greater_than, |up| {
	        name!(less_than, |down| {
	            let xs = sort_by(up.clone(), vec![6, 2, 4]);
	            let ys = sort_by(down.clone(), vec![5, 1, 4]);
	            // this will not compile
	            // println!("{:?}", merge_by(up, xs, ys).0);
	        })
	    });
	}

also see it [here](0115/gdp.rs)

### Conclusion

This implementation has to use a macro and a closure to mimic the usage of `coerce` and rank-2 types in haskell, but the end result is pretty similar.

There's a chance that this actually _does_ result in some overhead in the executable,
because multiple instances of `name` might be created for each `Name` type,
but maybe that can be improved (without losing the gdp stuff) by using `dyn` types?

I've also thought about using rust lifetimes instead of `PhantomData` types but I haven't figured out a way to
get the compiler to create unique, non-intersecting lifetimes.



[Rust]: https://www.rust-lang.org/
[GDP]: https://kataskeue.com/gdp.pdf
[phantom_types]: https://wiki.haskell.org/Phantom_type
[`Coercible`]: https://wiki.haskell.org/GHC/Coercible
[`PhantomData`]: https://doc.rust-lang.org/std/marker/struct.PhantomData.html
