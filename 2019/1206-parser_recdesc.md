<pmeta id="created">2019-12-06T12:00:00-05:00</pmeta>
<pmeta id="title">Parsing 2: recursive descent</pmeta>

[Last time](./1109-parser1_PDA.html)
I tried to parse our toy logical calculator language using a hand-constructed push-down automata.

Today, I'll introduce another method of writing parsers: recursive descent.
In contrast to PDAs, recursive descent parsers read a lot like the original grammar, and so require a little less mental translation to write.

However, the problem of infinite recursion is introduced, and it can be especially tricky to avoid infinite recursion in recursive descent parsers for grammars that are recursive. 

The basic crux of a recursive descent parser is that you define complex parsing functions in terms of simpler parsing functions.
Often the functions you define can be mapped 1-1 to non-terminal expressions in your grammar.

Starting from The Bottom
---

We need some simple starting parsers to start with that don't reference any others, so let's define `Pchar`

	Pout
	Pchar(Pin in, char c) {
		if (in.buf[0] == c)
			return (Pout){ .parsed=1 };
		return PARSE_FAIL;
	}

In this example I make use of some types (`Pout`, `Pin`, and a constant called `PARSE_FAIL`), which can be defined as follows

	typedef struct {
		int parsed;
		bool pres;
	} Pout;
	typedef struct {
		char* buf;
	} Pin;
	const Pout PARSE_FAIL = (Pout){ .parsed=-1 };

The `Pout` struct contains the number of chars parsed (or -1 if parsing failed), as well as any information that needs to be threaded back to the caller.
Since we are interested only in the evaluated logical string, we only ever need to pass back a boolean value (`bool pres`).
If you're building a parser for the purpose of, say, pretty-printing the string, you'd want to return something with a little more information (like an Abstract Syntax Tree or "AST").

As a reminder, our grammar is defined as

	expr ::=
		| 't'
		| 'f'
		| '(' expr ')'
		| '!' expr
		| expr '&' expr
		| expr '|' expr
		;

So, let's try parsing something simple, like `'t'`.

	Pout
	Ptrue(Pin in) {
		Pout out;
		if (out = Pchar(in, 't'), out.parsed == -1)
			return PARSE_FAIL;
		out.pres = true;
		return out;
	}

and I guess a similar one for parsing false values

	Pout
	Pfalse(Pin in) {
		Pout out;
		if (out = Pchar(in, 'f'), out.parsed == -1)
			return PARSE_FAIL;
		out.pres = false;
		return out;
	}

It's certainly a little more verbose than our grammar, but it sort of makes sense, and let's us parse the simpler grammar of

	expr ::= 't' | 'f'

let's implement the `expr`

	Pout
	Pexpr(Pin in) {
		Pout out;
		if (out = Ptrue(in), out.parsed != -1)
			return out;
		if (out = Pfalse(in), out.parsed != -1)
			return out;
		return PARSE_FAIL;
	}

and a `main` that tests it

	int
	main(void) {
		Pin in[] ={
			{ .buf = "t" },
			{ .buf = "f" },
			{ .buf = "e" }
		};
		Pout out;

		for (int i=0; i < sizeof(in)/sizeof(in[0]); i++) {
			out = Pexpr(in[i]);
			printf("%s = %d [%d]\n", in[i].buf, out.pres, out.parsed);
		}

		return 0;
	}

Here it is all in one file: [recdesc0.c](1206/recdesc0.c)

The Descent
---

Now we can move to parens, and not, which are both defined recursively in terms of `expr`.

	Pout
	Ppar(Pin in) {
		Pout out, ret={0};
		if (out = Pchar(in, '('), out.parsed == -1)
			return PARSE_FAIL;
		ret = out;
		in.buf += out.parsed;
		if (out = Pexpr(in), out.parsed == -1)
			return PARSE_FAIL;
		ret = (Pout){
			.parsed = ret.parsed + out.parsed,
			.pres = out.pres
		};
		in.buf += out.parsed;
		if (out = Pchar(in, ')'), out.parsed == -1)
			return PARSE_FAIL;
		ret.parsed += out.parsed;
		return ret;
	}


Let's add not, which needs to parse an expression and return the logical not of it

	Pout
	Pnot(Pin in) {
		Pout out, ret = {0};
		if (out = Pchar(in, '!'), out.parsed == -1)
			return PARSE_FAIL;
		ret = out;
		in.buf += out.parsed;
		if (out = Pexpr(in), out.parsed == -1)
			return PARSE_FAIL;
		ret = (Pout){
			.parsed = ret.parsed + out.parsed,
			.pres = !out.pres
		};
		return ret;
	}

and last add those cases to `Pexpr`, and some extra cases to see that it works

	Pout
	Pexpr(Pin in) {
		Pout out;
		if (out = Ptrue(in), out.parsed != -1)
			return out;
		if (out = Pfalse(in), out.parsed != -1)
			return out;
		if (out = Ppar(in), out.parsed != -1)
			return out;
		if (out = Pnot(in), out.parsed != -1)
			return out;
		return PARSE_FAIL;
	}
	
	main ...
		Pin in[] = {
			...
			{ .buf = "!t" },
			{ .buf = "(t)" },
			{ .buf = "!(!f)" },
			{ .buf = "(" },
			{ .buf = ")" },
			{ .buf = "!" }
		};

Here it is all in one file: [recdesc0.c](1206/recdesc1.c)

Binops in the Deep
---

We are speeding right along, so `and` and `or` are next

	Pout
	Pand(Pin in) {
		Pout out, ret = {0};
		if (out = Pexpr(in), out.parsed == -1)
			return PARSE_FAIL;
		ret = out;
		in.buf += out.parsed;
		if (out = Pchar(in, '&'), out.parsed == -1)
			return PARSE_FAIL;
		ret.parsed += out.parsed;
		in.buf += out.parsed;
		if (out = Pexpr(in), out.parsed == -1)
			return PARSE_FAIL;
		ret = (Pout){
			.parsed = ret.parsed + out.parsed,
			.pres = ret.pres && out.pres
		};
		return ret;
	}
	
	Pout
	Por(Pin in) {
		Pout out, ret = {0};
		if (out = Pexpr(in), out.parsed == -1)
			return PARSE_FAIL;
		ret = out;
		in.buf += out.parsed;
		if (out = Pchar(in, '|'), out.parsed == -1)
			return PARSE_FAIL;
		ret.parsed += out.parsed;
		in.buf += out.parsed;
		if (out = Pexpr(in), out.parsed == -1)
			return PARSE_FAIL;
		ret = (Pout){
			.parsed = ret.parsed + out.parsed,
			.pres = ret.pres || out.pres
		};
		return ret;
	}
	
	Pout
	Pexpr(Pin in) {
		Pout out;
		if (out = Ptrue(in), out.parsed != -1)
			return out;
		if (out = Pfalse(in), out.parsed != -1)
			return out;
		if (out = Ppar(in), out.parsed != -1)
			return out;
		if (out = Pnot(in), out.parsed != -1)
			return out;
		if (out = Pand(in), out.parsed != -1)
			return out;
		if (out = Por(in), out.parsed != -1)
			return out;
		return PARSE_FAIL;
	}
	
	main ...
		Pin in[] = {
			...
			{ .buf = "t&f" },
			{ .buf = "t|f" }
		};
		...
	

run it and...

	t = 1 [1]
	f = 0 [1]
	Segmentation fault (core dumped)

Hmm, the `"e"` input _was_ supposed to result in an error, but _our_ error, not a segfault.
If you remove that test case, you'll find the other expected errors result in segfaults as well.
If you remove all the error test cases, we also result in

	t = 1 [1]
	f = 0 [1]
	!t = 0 [2]
	(t) = 1 [3]
	!(!f) = 0 [5]
	t&f = 1 [1]
	t|f = 1 [1]

those last two cases are not right, I want it to parse the whole string, but instead, it's short-circuiting at the first `t`.
We could put the `and` and `or` cases before the others, so it tries those first.


	Pout
	Pexpr(Pin in) {
		Pout out;
		if (out = Pand(in), out.parsed != -1)
			return out;
		if (out = Por(in), out.parsed != -1)
			return out;
		if (out = Ptrue(in), out.parsed != -1)
			return out;
		if (out = Pfalse(in), out.parsed != -1)
			return out;
		if (out = Ppar(in), out.parsed != -1)
			return out;
		if (out = Pnot(in), out.parsed != -1)
			return out;
		return PARSE_FAIL;
	}

Perfect, now just start 'er up and...

	Segmentation fault (core dumped)

Yay, nothing works!
Let's put back the test cases we removed and move `Por` and `Pand` cases back to the bottom of `Pexpr`.

Here it is all in one file: [recdesc2.c](1206/recdesc2.c)

Left Be Recursed
---

I like to start debugging with printf's before I get into interactive debugger land.
So let's instrument our functions with some prints to see if we can follow where control flow goes.


	Pout
	Pchar(Pin in, char c) {
		printf("'%c'? ", c);
		if (in.buf[0] == c)
			return (printf("T\n"), (Pout){ .parsed=1 });
		return (printf("F\n"), PARSE_FAIL);
	}

and running that we get

	't'? T
	t = 1 [1]
	't'? F
	'f'? T
	f = 0 [1]
	't'? F
	'f'? F
	'('? F
	'!'? F
	't'? F
	'f'? F
	'('? F
	'!'? F
	't'? F
	'f'? F
	'('? F
	'!'? F
	't'? F
	'f'? F
	'('? F
	... similar ...
	Segmentation fault (core dumped)

Here it is all in one file: [recdesc3.c](1206/recdesc3.c)

It looks like a neverending pattern of testing for `'t'`, `'f'`, `'('`, and `'!'`.
That matches the order that we try `Ptrue`, `Pfalse`, `Ppar`, and `Pnot` in `Pexpr`, but why does it repeat?
Because the next attempt after `Pnot` fails is `Pand`, and the first thing `Pand` tries is to match `Pexpr`, so we have a nice mutually recursive loop between the two functions.

There are a couple ways to iron this out, but the one I'll be presenting here is to break the mutually recursive dependence on the left-most non-terminal of `Pand` and `Por`.
I'll be honest, I know there's probably a lot of papers written on rewriting grammars to avoid left-recursion, but I've gotten by mostly by just doing a bunch of times.
So in this case, I'm going to try

	val ::= 't' | 'f' | '(' expr ')' | '!' expr
	expr ::=
		| val
		| val '&' expr
		| val '|' expr

I took all the non-left-recursive `expr`s and stuck them in another non-terminal called `val`, while and now the previously left-recursive and/or rules are non-left-recursive, because I've specified that they _must_ match a non-left-recursive rule.

This thankfully does *not* result in a smaller grammar, but it does thankfully restrict parsing based on this grammar.

For instance, with the previous grammar I could have generated an output like:

	            expr
	             |
	     expr   '&'   expr
	      |            |
	expr '|' expr     'f'
	't'      't'  
	
	final output: "t|t&f"

The new grammar can still generate this, it's just that the tree must look different:

	    expr
	     |
	val '|' expr
	 |        |
	't'  val '&' expr
	      |       |
	     't'     val
	              |
	             'f'
	
	final output: "t|t&f"

If we're generating an AST or evaluating as soon as we can, this means the associativity of `'|'` and `'&'` becomes _strictly_ right-associative: `t|t&f == t|(t&f)`.
This isn't a problem if the operators are the same like `t|(t|f) == (t|t)|f`, but becomes an issue when the operators are mixed, and are the same precedence like the example above.
Many languages give logical AND an higher precedence than logical OR, and that follows from 
[boolean algebra](https://en.wikipedia.org/wiki/Boolean_algebra#Monotone_laws),
where AND is similar to multiplication and OR similar to addition.
So let's add this distinction to our parsing grammar:

	val ::= 't' | 'f' | '(' expr ')' | '!' val
	expr0 ::= val | val '&' expr0
	expr ::= expr0 | expr0 '|' expr

> I totally messed this up the first time I wrote it, and made `|` higher precedence than `&`.  It was an easy mistake to spot, and easy to fix.
> It's why I like: learning by doing, tests, theory to practical.
> Likewise, handling AND/OR precedence, I totally forgot that NOT will also have a higher precedence than those two, that's why the grammar has `'!' val`

so now `"t|t&f"` can be produced in the following way:

	        expr
	         |
	expr0   '|'   expr
	 |             |
	val     expr0 '&' expr
	 |       |         |
	't'     val       expr0
	         |         |
	        't'       val
	                   |
	                  'f'
	
	final output: "t|t&f"

and we preserve commutativity rules of logical OR and logical AND.

To Implement a Grammar
---

Let's add new rules for `Pval`, `Pexpr0`, and `Pexpr`:

	Pout
	Pval(Pin in) {
		Pout out;
		if (out = Ptrue(in), out.parsed != -1)
			return out;
		if (out = Pfalse(in), out.parsed != -1)
			return out;
		if (out = Ppar(in), out.parsed != -1)
			return out;
		if (out = Pnot(in), out.parsed != -1)
			return out;
		return PARSE_FAIL;
	}
	
	Pout
	Pexpr0(Pin in) {
		Pout out;
		if (out = Pand(in), out.parsed != -1)
			return out;
		if (out = Pval(in), out.parsed != -1)
			return out;
		return PARSE_FAIL;
	}
	
	Pout
	Pexpr(Pin in) {
		Pout out;
		if (out = Por(in), out.parsed != -1)
			return out;
		if (out = Pexpr0(in), out.parsed != -1)
			return out;
		return PARSE_FAIL;
	}

and we'll also need to change up our `Por`, `Pand`, and `Pnot` functions

	Pout
	Pnot(Pin in) {
		Pout out, ret;
		if (out = Pchar(in, '!'), out.parsed == -1)
			return PARSE_FAIL;
		ret = out;
		in.buf += out.parsed;
		if (out = Pval(in), out.parsed == -1)
			return PARSE_FAIL;
		ret = (Pout){
			.parsed = ret.parsed + out.parsed,
			.pres = !out.pres
		};
		return ret;
	}
	
	Pout
	Por(Pin in) {
		Pout out, ret;
		if (out = Pexpr0(in), out.parsed == -1)
			return PARSE_FAIL;
		ret = out;
		in.buf += out.parsed;
		if (out = Pchar(in, '|'), out.parsed == -1)
			return PARSE_FAIL;
		ret.parsed += out.parsed;
		in.buf += out.parsed;
		if (out = Pexpr(in), out.parsed == -1)
			return PARSE_FAIL;
		ret = (Pout){
			.parsed = ret.parsed + out.parsed,
			.pres = ret.pres || out.pres
		};
		return ret;
	}
	
	Pout
	Pand(Pin in) {
		Pout out, ret;
		if (out = Pval(in), out.parsed == -1)
			return PARSE_FAIL;
		ret = out;
		in.buf += out.parsed;
		if (out = Pchar(in, '&'), out.parsed == -1)
			return PARSE_FAIL;
		ret.parsed += out.parsed;
		in.buf += out.parsed;
		if (out = Pexpr0(in), out.parsed == -1)
			return PARSE_FAIL;
		ret = (Pout){
			.parsed = ret.parsed + out.parsed,
			.pres = ret.pres && out.pres
		};
		return ret;
	}

and let's add `"t|t&f"` to our tests because we've been talking about it so much, as well as `"!t&f"`.
Executing now should result in:

	t = 1 [1]
	f = 0 [1]
	e = 0 [-1]
	!t = 0 [2]
	(t) = 1 [3]
	!(!f) = 0 [5]
	( = 0 [-1]
	) = 0 [-1]
	! = 0 [-1]
	t&f = 0 [3]
	t|f = 1 [3]
	t|t&f = 1 [5]
	!t&f = 0 [4]

Here it is all in one file: [recdesc4.c](1206/recdesc4.c)

Conclusion
---

We built a parser using the recursive descent method.
This post got a little bit more into theory of grammars, and I demonstrated an example of rewriting a grammar to make it easier to parse.
While I also rewrote the grammar for the PDA, the rewrite felt, at least to me, a little less magical for this recursive descent method.
I tried a couple different ways of defining the state machine for the PDA before settling on one that was simple, but for this, I could actually explain my grammar transformation.

Example code for each section is available, as well as an interactive example that interprets input from stdin: [recdesc.c](1206/recdesc.c).

Thanks for reading, next time I will either go into parser-combinators or yacc and the idea of the LR(1) parser.

word,


