<pmeta id="created">2023-10-11</pmeta>
<pmeta id="title">Syntax Capabilities</pmeta>

I have a bit of a half-baked idea in my head.
It is based on the complaints around having programming
languages that are too powerful or complex for the task
at hand. I think you should have some annotation to dumb
down the language allowed in a file.

For instance, Starlark[0] was created to simplify the
runtime semantics of python. This allowed people to
write bazel configuration in a syntax that was familiar
and allowed certain programming constructs, but wasn't
so powerful that they needed a full python interpreter.
All the examples on "Accidentally Turing Complete"[1].
These were all intended to be simpler
languages, but with the introduction of some construct
became powerful enough to simulate any other program.

Another instance of a place where you want a language
that is powerful enough but not too powerful is eBPF[2].
There is a verifier that tries to make sure your code
is not creating infinite loops or other nasty runtime
behaviour. This _can_ be enforced by restricting the
language itself to disallow unbounded recursion or
unbounded loops, but C allows both of those.
Related is real-time computing requirements, which can
include restraints like "this block of code should
complete within some number of cycles/amount of time".
These problems can be solved by writing programs in C
and implementing some static analysis, but as I
understand, that static analysis is hard to write, and
can require manual annotations or edits to the source
to please the analysis.

Lastly, languages like C++[4], Rust[5] or Zig[6] all have syntax
to indicate "this code should be run at compile-time"
usually referred to as "constant expressions", and usually
compile-time evaluation is restricted (but not always, for
instance there's a Jai demo where he runs the full game
with network calls and file IO at compile time). The reason
constant evaluation is often restricted is that it should
be fast because people don't like waiting on compilers,
and people (aka me) generally like reproducible builds that don't
depend on having the exact same build environments down
to the processor and whatever ip address your build machine
had at the time of building, so that information should
be abstracted away at compile-time evaluation.


So my half-baked idea is this: a type system with a capabilities
tailored toward restricting syntax to ultimately restrict
semantics. I want to be able to write config in the same
language I write my program *but* my config parser should be
significantly simpler than my source code interpreter.

With that in mind, I think file-level is a nice boundary,
specifically because it's simple enough to check for some line at
the beginning like

    # capabilities: record,nat,constexpr
    
    foo = {
      a = 4,
      b = 5,
      c = const 4*4,
    }
    
    //bar = fun() { ... } // XXX ERROR, function declaration not permitted here, requires the fun capability

or

    # capabilities: fun[const]
    double = fun[const](a: nat) { const(a + a) }
    // sillyhead = fun[const]() { http.get("https://example.com") } // ERROR, http.get requires apply capability, which is not present in fun() [const]-> ? 

I'd like it to be part of the type system to also distinguish
between runnable scripts and definitions of runnable functions
intended for compilation. Eg

    # capabilities: apply,fun
    double = fun(a: nat) { a + a }
    double(2)

    # capabilities: fun
    double = fun(a: nat) { a + a }
    triple = fun(a: nat) { double(a) + a }
    // triple(4) // ERROR, this requires apply capability

I think the set of capabilities will have to be closed to ensure
someone doesn't expect their config parser to understand their magic
`frobnicate` capability that they added to their config files so
they can frobnicate all over the place. I think the most complex I
want to get is something like F-omega with subtypes[7], maybe with
linear typing because we'll have kinds anyway. I don't want dependant
typing because I suspect it makes implementation much more difficult
judging by different languages' hesitance to add features that
require dependant typing[8][9].


I think there's some prior art in "carving config languages out of
general purpose language" for instance JSON[10] and RON[11]. I
think there could be a benefit to making this more formal, and I
think capabilities are the way to do this.


For a reason why this should be part of the capabilities+type system,
consider that you want to define a function which can be compiled
to an eBPF program, along with the source around it that handles
loading and running the eBPF.

    # capabilities: fun
    double = fun[const](a: nat) { a + a }
    prog = fun[apply,const](a: nat) { double(a) }
    silly = fun[recurse](a: nat) { silly() }
    main = fun() {
      ebpf.run(prog); // OK
      ebpf.run(silly); // ERROR, ebpf.run has type fun(fun(nat) [apply,const]-> nat) -> (), but silly has type fun(nat) [recurse]-> !
    }

I'm not sure how I both allow compilation to a target platform, but
also to wait to compile until runtime (like in the eBPF case, we want
an eBPF binary version of `prog` not an x86 binary version of it),
maybe with some other type of constructor that indicates "compile
this to the runtime target" :shrug:, like I said, half-baked.


As for why anyone (aka me) would want this. I want to be able to write config in
the same language I write my normal data structures in. However, I also want the
tools I write to parse config files to remain simple and not have to implement
a cylindrical type checker because there's nothing stopping someone from adding
homoslopical equivalence types to my 12-factor app's config file so we can
set boolean config variables to "1", "true", "T", or "norway"; and anyway it's
already in the reference compiler for the general purpose language, so we can
just copy it from there.

[0]: https://github.com/bazelbuild/starlark
[1]: https://matt-rickard.com/accidentally-turing-complete
[2]: todo: eBPF
[4]: todo: c++ const eval
[5]: todo: rust const eval
[6]: todo: zig constexpr
[7]: todo: f-omega with subtypes
[8]: todo: rust dependant types
[9]: todo: haskell dependant types
[10]: todo: json
[11]: todo: rusty object notation
