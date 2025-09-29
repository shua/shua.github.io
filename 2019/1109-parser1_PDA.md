<pmeta id="created">2019-11-09T12:00:00-05:00</pmeta>
<pmeta id="updated">2019-11-29T12:00:00-05:00</pmeta>
<pmeta id="title">Parsing 1: PDA</pmeta>

I go back and forth reading/doing and now I'm trying to add teaching to the loop.
While I can't say if this will be usable by anyone but myself, it's some really informal blog posting on my thoughts for making a parser.

I like coding in C, because it makes me think about Data+Algorithms, and that's a different mindset than when I'm thinking in Type Theory.
So I tried giving some of this as an informal talk to some coworkers a couple weeks back.
It was nominally an introduction to yacc, but I think this will be a series of blog posts describing me trying to get some hands on understanding of different ways to build a parser.

This first post is both very hand-wavy and very nitty-gritty, so buckle up.
I'll be referencing C code throughout the post, but you can find the full file [parser.c].

The Language
---

First, let's look at a langauge that has some really simple stuff I want to be able to parse.

	(t|f)&t

Usually the starter language for parsing is some numeric calculator like dc, simple arithmetic.
This is even simpler, and my endgoal is quantum circuits, so logical arithmetic is a nice start.

The language is defined by the following BNF grammar

	expr ::=
		| 't'
		| 'f'
		| '(' expr ')'
		| '!' expr
		| expr '&' expr
		| expr '|' expr
		;

One nice feature of this is that it's a recursive grammar.
Simply stated above, it's a *left* recursive grammar, which will turn out to be really annoying in some future steps.


Finite State Machine
---

We can parse this with two states: expecting chars that start an expression, and expecting chars that can come after an expression.
Let's call these states respectively: `S` and `E`.

	  S E
	t E
	f E
	( S
	)   E
	! S
	&   S
	|   S

The table is meant to be read to find the next state given a current state and an input.
So "I'm in state `E` and I read in an '&', then the next state is `S`".
If there's no entry in the table, then that indicates a parsing error.

Here's an implementation in C of that state machine, hopefully you can see the switches correspond to first checking the column in the table, then checking the row.

	typedef enum State { S_S, S_E } State;

	int
	parse() {
		State s;
		int c;

		while((c=getchar(stdin)) != EOF &&  c != '\n')
		switch (s) {
		case S_S: switch (c) {
			case 't': s = S_E; break;
			case 'f': s = S_E; break;
			case '!': s = S_S; break;
			case '(': s = S_S; break;
			default: err("Unexpected");
			} break;

		case S_E: switch (c) {
			case '&': s = S_S; break;
			case '|': s = S_S; break;
			case ')': s = S_E; break;
			default: err("Unexpected");
			} break;
		}

		return s == E;
	}

The nice thing is parsing is never ambiguous, that is, it's always clear given the current state and input what the next state should be.
The table above doesn't _actually_ represent an acceptor for our grammar though.
It recognizes "t & f" sure, but it recognizes too much.
For instance, it thinks "))))" is a valid input.

Since our grammar includes nesting parentheses, we'll need to keep track of that.
Could just introduce a counter, that increases for '(' and decreases for ')'.
Check that it never goes negative, and that we're back at 0 at the end, and we should be good.

	int pars = 0;
	...
		case '(': ... ; pars++; break;
	...
		case ')': ... ; if (pars == 0) err("Unexpected"); pars--; break;
	...
	if (pars != 0) err("Expected more");
	return s == S_E;


Cool, that oughta work as an acceptor.

What happens if we want to actually evaluate it though?

Evaluating
---

To think like a human for a second: for expressions like "t & f | t" we can read it from left to right, and chunk it up like

	t & f ...
	||||| ^^^ forget about what was there for now
	^^^^^ we can just evaluate this leftmost "t & f" which is f

	    f ...
	    f | t  which is "t"
	    ^ replace the leftmost expression with its value, in this case f
	
	t & f | t is "t"

We didn't really need to peek-ahead or remember much more than "what is the left operand" (last computed value t/f) for any given step.
Fairly simple, and doesn't require much brain space.

To think like a _computer_: we got to be a little more precise.
If we're going character by character, we only need to remember 2 things:

	    t ... we've got 't'
	  t & ... an operator, so we've got 't &' and expecting t/f next?
	t & f ... replace it with the value of "t & f" which is "f"
	    f ...
	  f | ... there better be t or f next
	f | t     there is, replace it with value of "f | t" which is "t"

so we have to remember the left operand and the operator if we're stepping character by character.

You may notice my example doesn't use the not '!' or parentheses '(',')'.
Let's restrict the grammar for a minute and just consider:

	expr ::= 't' | 'f' | expr '&' expr | expr '|' expr

Which is pretty easy to parse and evaluate the expressions

	typedef enum Op { And, Or } Op;

	bool
	eval(bool l, Op op, bool r) {
		switch (op) {
		case And: return l && r;
		case Or: return l || r;
		}
	}

	typedef enum State { S_S, S_E } State;

	int
	parse(bool* b) {
		bool l;
		Op op;
		int c;
		State s = S_S;

		while ((c=getchar(stdin)) != EOF && c != '\n')
		switch (s) {
		case S_S: switch (c) {
			case 't': *b = eval(l, op, true); s = S_E; break;
			case 'f': *b = eval(l, op, false); s = S_E; break;
			default: err("Unexpected");
			} break;
		case S_E: switch (c) {
			case '&': l = *b; op = And; s = S_S; break;
			case '|': l = *b; op = Or; s = S_S; break;
			default: err("Unexpected");
			} break;
		}

		return s == S_E;
	}

but how should we handle not and paren nesting?
We could handle not like we handle and/or, just there's no first argument to remember.

	enum Op { Not, And, Or };
	...
	eval(bool l, Op op, bool r) {
	...
		case Not: return !r;
	...
	parse(bool *b) {
	...
			case '|': ...
			case '!': op = Not; s = S_S; break;

Now parens are tricky, consider "t | (t & f)"
Can't just use a paren counter, because

	t | ...
	^^^ okay, store Or(t) for next value
	    ( ... )
	      ^^^ but next value is everything in here

uh, what if we just par++ and keep going?

	t | t ... ez
	    t ...
	  t & ...
	t & f ...
	  f )     uh, par-- looks good
	    f     we're done, but that's not right

if we don't evaluate the right-hand operand separately, then we're just ignoring the parens for evaluating, and can end up with a wrong answer.
Effectively what we did was transform "t | (t & f)" to "(t | t) & f" which isn't valid.

So, what to do?
We can't just add some more memory

	...
		bool l, l2;
		Op op, op2;
	...

because then we can only remember 2 operations back, but what if it's "t | (t | (t & f))"?


Push Down Automata
---

This is looking like we'll need to support some arbitrary depth of memory.
People, and computers can't do *arbitrary* memory, but we can write programs in a way that says: keep remembering until you physically cannot anymore.
For me that limit is like 3 things, but computers usually have a little more depth.

We're going to ask it to just keep remembering the list of operators before until it can finally evaluate them.
This combination of "left operatorand and operator" is "pushed down" onto a stack of others that may have been added before it.

Aside: this concept is some of that old gold of algorithms/computing referred to as a "stack" a "list" a "Last-In-First-Out (LIFO) queue" and even in some old papers a "cellar".

Anyway, we're going to implement a stack of ops using a list.
A stack is more descriptive of what you can do with it (push/pop) and list is how the data looks (head + tail).
The stack behaviour is where the "Push Down" comes from for "Push Down Automata".

	typedef enum Op { Not, And, Or } Op;
	typedef struct OpList {
		Op op;
		bool l;
		OpList* next;
	} OpList;

	OpList*
	push(OpList* os, Op op, bool l) {
		OpList* r = malloc(sizeof(OpList));
		*r = (OpList){ .op=op, .next=os };
		return r;
	}

	OpList
	pop(OpList* os) {
		OpList r = *os;
		free(os);
		return r;
	}

	bool
	eval(bool l, Op op, bool r) {
		switch (op) {
		case Not: return !r;
		case Or: return l || r;
		case And: return l && r;
		} 
	}

that looks good, let's write the parse function

	typedef enum State { S_S, S_E } State;

	int
	parse(bool* b) {
		int c;
		State s = S_S;
		OpList* os = NULL;

		while ((c=getchar(stdin)) != EOF && c != '\n')
		switch (s) {
		case S_S: switch (c) {
			case 't': *b = eval(os->l, os->op, true); s = S_E; break;
			                    ^^^^^ I don't feel too good about this, we initialized it to NULL, so this is just going to throw an error

maybe we can make sure it's not NULL by pushing a value on there to begin with?

		OpList* os = push(NULL, _, _)
		                        ^ but what Op should it be?

anything we start it out with translates expr to

	! expr   -- if we push Not
	_ & expr -- if we push And and some bool
	_ | expr -- if we push Or and some bool

I think we should just add some other Op variant that's like "do nothing".
Evaluating it on the line

			case 't': *b = eval(os->l, os->op, true); s = S_E; break;

should result in *b = true, so I think we have enough to fill it in.

	typedef enum Op { Nop, Not, And, Or };
	...
	eval(...) {
	...
		case Nop: return r;
	...


	int
	parse(bool* b) {
		int c;
		State s = S_S;
		OpList* os = push(NULL, Nop, *b);

		while ((c=getchar(stdin)) != EOF && c != '\n')
		switch (s) {
		case S_S: switch (c) {
			case 't': *b = eval(os->l, os->op, true); s = S_E; break;
			case 'f': *b = eval(os->l, os->op, false); s = S_E; break;
			case '!': os = push(os, Not, *b); break;
			case '(': os = push(os, Nop, *b); break;
			default: err("Unexpected");
			} break;

		case S_E: switch (c) {
			case '&': os = push(os, And, *b); s = S_E; break;
			case '|': os = push(os, Or, *b); s = S_E; break;
			case ')': ;
				if (!os->next) err("Unexpected");
				OpList ol = pop(os);
				os = ol.next;

				if (ol.op != Nop) err("Unexpected");
				*b = eval(os->l, os->op, ol.l);
				break;
			} break;
		}

		if (os && os->next) err("Expected more");

		pop(os);

		return s == S_E;
	}

The case ')' line is maybe not really an obvious translation from the previous

	if (pars == 0) err("Unexpected"); pars--;

but in that simpler case, it was checking to make sure it hadn't read more ')' than there were '(' preceding.

Correction
---

The code presented won't actually run correctly, and this is because we _still_ haven't handled parens and nesting correctly.
Once an op like `Not`, `And`, or `Or` is evaluated, that op should be popped from the top of the stack.
We could change the `case 't'` line to read something like

	case 't': *b = eval(os->l, os->op, true); os = os->op != Nop ? pop(os).next : os; ...

but I think instead our understanding of the effects of evaluation were incomplete.

I had only mentioned how `b` changes under evaluation, but it looks like the value of `os` also changes depending on the op being evaluated.
Thus, let's change `eval` to reflect this

	OpList*
	eval(OpList* os, bool* b) {
		switch(os->op) {
		case Nop: break;
		case Not: *b = !*b; os = pop(os).next; return os;
		case And: *b = os->l && *b; os = pop(os).next; return os;
		case Or: *b = os->l && *b; os = pop(os).next; return os;
		}
	}

and its usage

	case 't': *b = true; os = eval(os, b); s = S_E; break;
	case 'f': *b = false; os = eval(os, b); s = S_E; break;
	...
	case ')':
		if (!os->next || os->op != Nop) err("Unexpected");
		os = pop(os).next;
		os = eval(os, b);
		break;

The final program with all these changes (as well as some debugging additions) is available as [parser.c].

As an addendum, and because I enjoy words, what we've made here can be considered a _stack machine_, specifically a _pushdown machine_ (because it does not permit arbitrary depth operations in the stack, it really just works with the head).
However, it also has a single boolean register (`b`), and so could be considered an _accumulator_ which is a name used for machines with a single register.

Conclusion
----------

We defined a grammar and wrote a nice little parser in C for it.
The way I decided to break it up was to build up the parsing understanding first, then build up understanding on how to evaluate the actual expression.

Next time, I'll write about either yacc parsers, or maybe a recursive descent version.
I may fill in this post later with some asides and more links to the theory that underpins the decisions or designs of parsers.

sick

[parser.c]: 1109-parser1_PDA/parser.c

