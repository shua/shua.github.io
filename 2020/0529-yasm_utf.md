<pmeta id="created">2020-05-26T12:00:00-05:00</pmeta>
<pmeta id="title">Code-vid: yasm utf string ops</pmeta>

From the [previous work in UEFI images], I got a new itch: extend [`yasm`] to support
[`nasm`'s utf string ops].

For a minimal example, I wanted to write
```
; example.s
dw __utf16be__("hello")
```

and have
```
$ yasm example.s  -o example.out
$ od example.out -x
0000000 0068 0065 006c 006c 006f
```

Digging
-------
`yasm` is a C codebase that's currently split into a frontend and a backend.
The "frontend" encompasses the tokenization and parsing of source code,
and the "backend" encompasses assembling codes and data into an object file.

My change would need two things implemented:
- recognizing and parsing the `__utf*__` ops correctly
- translating the utf8 encoded string in the string op to some other unicode encoding

the first naturally fits in the "frontend" code, and the second in the "backend".

Parsing
-------
`yasm` uses a cool preprocessor called "[re2c]" to generate its tokenizer as C source.
I'd never heard of it before, but the tool reads essentially annotated C source and generates
some state machine code from the annotations.

I've used `yacc` and the like to produce parsers for toy langs before,
and the theory is very similar, but re2c seems a little closer to a pure C state machine parser.
I think it's pretty neat, and while many modern languages cry about extensibility,
it's kind of a self-inflicted problem with programmers who are uncomfortable 
writing parsers, preprocessors, and code generators.
Source code is (usually) just text, so every language can be seen as just a
compile target for a slightly more powerful language.

Anyway, I'm only interested in extending the nasm parser, so changes go in
`modules/parsers/nasm` where I added a new token type of `STRING_OP` that is
emitted by any matches on `__utf*__`  style prefixes.

Some snippets of adding the encoding data are below:
```
// type def libyasm/coretype.h
typedef enum yasm_utfenc { UTF8 = 0, UTF16LE, UTF32LE, UTF16BE, UTF32BE } yasm_utfenc;

// struct def modules/parsers/nasm/nasm-parser-struct.h
    struct {
        char *contents;
        yasm_utfenc enc; // <- added this
        size_t len;
    } str;

// usage modules/parsers/nasm/nasm-token.re 
    /* string/character constant values */
    '__utf16__' | '__utf16le__' {
        lvalp->str.enc = UTF16LE;
        RETURN(STRING_OP);
    }
    '__utf32__' | '__utf32le__' {
        lvalp->str.enc = UTF32LE;
        RETURN(STRING_OP);
    }
    '__utf16be__' {
        lvalp->str.enc = UTF16BE;
        RETURN(STRING_OP);
    }
    '__utf32be__' {
        lvalp->str.enc = UTF32BE;
        RETURN(STRING_OP);
    }
```

Next I added parsing rules that `STRING_OP` should be proceeded by `'(' STRING ')'`.
When that sequence of tokens is matched, a new data value is created with the
value of the `STRING` token which is encoded according to the `STRING_OP`.
The actual encoding is done by some "backend" code.
```
// modules/parsers/nasm/nasm-parse.c
    if (curtok == STRING_OP) {
        yasm_utfenc enc = STRING_val.enc;
        get_next_token();
        if (curtok != '(') { ...ERR... }
    
        get_next_token();
        if (curtok != STRING) { ...ERR... }
    
        dv = yasm_dv_create_string(STRING_val.contents, STRING_val.len, enc);
        if (!dv) {
            yasm_error_set(YASM_ERROR_GENERAL, N_("error encoding utf"));
        }
    
        get_next_token();
        if (curtok != ')') { ...ERR... }
        ...
```

Encoding
--------
I used [unicode's documentation] as well the helpful [w3m documentation]
on different unicode encoding and decoding schemes.
I won't recreate the specifics here, but the higher-level was
1. if the output is utf8, then just copy input to a dataval object and return that
2. set `utfenc` to the proper (16/32bit) encoding function, and `be` to true/false depending on if the encoding is big-endian or not
3. if there's no more input, then create the dataval from the buffer and return it
4. else decode a 32bit codepoint from input
5. encode the codepoint using `utfenc` and `be` and append to the buffer
6. go back to 3

steps 3-6 are copied in a snippet below:
```
// libyasm/bc-data.c
    unsigned int cpt;
    int j=0;
    buf = yasm_xmalloc(bufn);
    for (int i=0; i<len;) {
        if (j > bufn)
            goto encodeerr;
        int read = next_codepoint(&cpt, raw+i, len-i);
        if (read <= 0)
            goto encodeerr;
        i += read;
        int wrtn = utfenc(buf+j, cpt, be);
        if (wrtn <= 0)
            goto encodeerr;
        j += wrtn;
    }
    bufn = j;
```

If you want to read the actual implementation it's available currently on [a PR].

Testing
-------
I really wanted an automated way to test this things worked as I expected,
luckily the yasm project has some testing setup I could use.
I found it a bit tricky to get setup and running, and was basically compiling
the testing code and running them manually because I couldn't get the whole
test running scripts to work.

```
$ mkdir build && cd build && cmake .. && make $$ cd ..
$ cp build/yasm yasm
$ make test_hd
clang     test_hd.c   -o test_hd
$ srcdir=$PWD
$ libyasm/tests/libyasm_test.sh
Test libyasm_test: ...........E.......................... +37-1/38 97%
 ** E: incbin returned an error code!
$ cat results/incbin.ew
-:1: error: `incbin': unable to open file `stamp-h1'
```

I have no idea what generates that `stamp-h1` file, but all the other tests pass,
which makes me think I'm pretty much good.

I decided to add my own test to exercise the code I had added and written.
I only tested the happy cases of each string op, and I didn't manage to find
meaningful codepoints to test surrogate pairing in utf16\* encodings or longer
utf8 clusters.
I have no reason to believe it _won't_ work for higher codepoints,
but they're currently not tested.

Similarly, no idea if I added a data leak or not.
The parser code, and some of the backend code does allocations and frees
that were throwing me off, and it's unclear to me who owns what data
that get's passed around, caller or callee.

The PR
------
There's [a PR] open to add this feature to yasm and where I've asked some questions
about testing and data leaks above, but I haven't seen a lot of
movement on that codebase or the PRs, so I don't have a lot of hope for it.
While this was a fun dive into a foreign codebase, I wonder if people are
using some other opensource nasm-like assembler, and that's why development
on yasm has stagnated.

Some Corollary Thoughts
-----------------------
It was a nice stretch, and along the way I cemented a couple insights into myself:
The first is that I really like reading and implementing clear specs.
I guess the alternative is just hacking something together, and I like that too,
but there's an enjoyment I get from perusing the encoding/decoding specs in
unicode that I really miss in hack projects.

The second is related to the re2c program used in the yasm source and is 
more a _feely_ thing in that that I am comforted knowing that I can extend 
any language I want to by writing preprocessors and compilers for more 
interesting languages on top of it.

I write a lot of Java in my day job.
It's been a slog getting Lombok accepted, which is a text preprocessor
that reduces a lot of repetitive, almost _formulaic_ Java boilerplate.
I can't imagine trying to pitch custom DSL's or any other preprocessor
to my team or any other team I know.
I can think of many ways to implement a DSL on top of other base languages,
but I like the simplicity of just including a transpiler in your project instead
of relying on syntactic extension features or text macros.

Having leaned into Rust a little more, and weirdly doing a lot of prolog
on the side, I still like C for hacking and testing ideas.
I really like the more general idea, however burdensome, of extending a 
minimal base language with DSLs that to do what I want,
instead of jumping to a higher-level language just to use a couple things I don't understand.



[previous work in UEFI images]: 0529-uefi.html
[`yasm`]: https://yasm.tortall.net/
[`nasm`'s utf string ops]: https://www.nasm.us/doc/nasmdoc3.html
[re2c]: https://re2c.org/
[unicode's documentation]: https://www.unicode.org/versions/Unicode13.0.0/ch03.pdf#G7404
[w3m documentation]: https://www.w3.org/TR/encoding/
[a PR]: https://github.com/yasm/yasm/pull/147
