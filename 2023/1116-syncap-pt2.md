<pmeta id="created">2023-11-16</pmeta>
<pmeta id="title">Syntax Capabilities pt. 2</pmeta>

As per my [previous post][syncap1], I think there are benefits to restricting which
language constructs are available in a certain scope. I'm thinking of what
the downsides could be, and one of the things that comes to mind is the
different cases in Rust where some language construct works in some spot
but not in others. For example, "impl trait" syntax in Rust is loosely a way of
saying a type exists that implements a given trait, but without naming
that type. It's used in function signatures either as syntactic sugar for
generic input types, or as a way of returning opaque types

    trait Trait {}
    struct Bar;
    impl Trait for Bar {}

    // this is a sort of normalized form of the fn signature
    fn foo<T: Trait>(a: T) -> Bar { Bar }
    // with impl Trait syntax, we can abbreviate input types
    fn foo_in(a: impl Trait) -> Bar { Bar }
    // or we can elide output types
    fn foo_out<T: Trait>(a: T) -> impl Trait { Bar }
    // we can even do both
    fn foo_inout(a: impl Trait) -> impl Trait { Bar }

It can be used in a lot of places that a type can be used...but not every place.
This is kind of frustrating. For instance, `async` relies on return position
impl traits or "RPIT" so 

    struct Bar;
    async fn foo() -> Bar { Bar }
    // is actually
    fn foo() -> impl Future<Output=Bar> { ... }

So here syntax (`impl Trait`) is allowed in function returns, but frustratingly,
it is not allowed in trait method return position ("RPITIT"), so

    trait Trait {
      fn foo() -> impl OtherTrait; // ERROR: not allowed
    }

This same kind of frustration came up for me when learning C.
In C, you can define functions and values in the file scope, and you can
define values and call functions inside a function, but you cannot (without
non-standard extensions), define functions inside functions or call functions
at file scope. So we run into some annoying errors like

    int foo = make_foo(); // ERROR: can't call functions in static scope
    int foo2 = 2; // all good

    int bar() {
      int quux() {} // ERROR: can't define fuction in function
      int foo3 = make_foo(); // all good
    }

I'm not sure if I have an answer to this other than: keep syntax as consistent
as you can. I mean, when I read programming language theory papers, they
usually don't have a bunch of exceptions in their grammars, it's rather something like

     var x,y,z
    expr e ::= n | e(e) | fun(x: t) e | let x = e in e
    type t ::= nat | t -> t

There's not instead

    expr(file) e_f ::= n | let x = n in e_f | fun(x: t) e
    expr(fun)  e   ::= n | let x = e in e | e(e)

because it is cumbersome to keep a bunch of sort-of equivalent expression
grammars in your head. I don't really have a theory for why restricting
grammar with explicit capability syntax is better than having implicitly
many similar grammars other than in this case explicitly having to list
which syntax of all available is available *in this context* forces people
to think about it more. Maybe I can also add some kind of reasoning and
theory around this instead of simply having a bunch of ad-hoc rules in actual 
languages like "oh you can't do that here because we haven't implemented it yet".


I think part of making the capabilities explicit means people will be more
likely to keep to certain well-defined subsets. This reminds me of roc's
concept of [platforms][roc platform] which kind of codifies conventions used when
targetting different environments or usecases. I also recently saw Niko
Matsakis' [post on profiles][rust profiles] in Rust which seems to be
targetting the same issue.

Lastly, this feels similar to a type-and-effect system, where capabilities
are like effects, except I think of this as a closed world, so there is a
bounded universe of the most unrestricted language, and that is what the
reference compiler must handle, but there are many little restricted subsets
which simpler programs can parse, execute, or transform easily, with a very
simple and explicit marker that the syntax is restricted to a known subset.

[syncap1]: https://isthisa.website/2023/1011-syntax_capabilities.html
[roc platform]: https://github.com/roc-lang/roc/wiki/Roc-concepts-explained#platform
[rust profiles]: https://smallcultfollowing.com/babysteps/blog/2023/09/30/profiles/

