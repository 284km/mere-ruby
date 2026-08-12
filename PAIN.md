# Pain found writing mere-ruby

A dogfood log: what implementing a Ruby subset interpreter surfaced
about Mere itself.

## M11. `str_join` loses embedded NUL bytes — C backend only

mere-ruby's `Zlib::Deflate.deflate` returned streams CRuby rejected with
`invalid stored block lengths`, and I spent a while blaming the
compressor. It was the four-line bridge that turns a byte vector back
into a String:

```mere
str_join "" (list of chr bytes)
```

The reduction:

```mere
let a = chr 0;
let b = chr 65;
str_join "" (Cons (b, Cons (a, Cons (b, Nil))))
```

| backend | bytes |
|---|---|
| interpreter | `65, 0, 65` |
| C | `65, 65, 0` |

The **length is right** and the bytes are all present — they are in the
wrong order. `str_join` computes the total correctly but copies with
NUL-terminated semantics, so the non-zero bytes compact to the front and
the tail is left zeroed. `++` is correct on both backends; only `str_join`
diverges.

That shape is nasty in exactly the way a wrong length would not be:
`str_len` agrees, a text round trip agrees, and the corruption only shows
on data that contains a zero byte. Every compressed stream contains one.

mere-ruby now builds the string by halving concatenation with `++`
(O(n log n), and correct), and compresses for real: the system zlib
accepts what `Zlib::Deflate.deflate` writes here.

There is an older note in this project's own memory that Mere's `str` is
NUL-terminated and binary should cross boundaries as hex. That note was
right, and I talked myself out of it because mere-ruby's *String* is a
length-carrying handle. It is — but the Mere `str` inside it is not, and
the bridge builds one.

## M10. The lambda lifter drops a capture, chosen by name

Vendoring mgz under `.mere_modules/` and importing it into mere-ruby's
~21k-line `main.mere` produced C that would not compile. The lifted
function for `find_match`'s inner `mlen` still referenced `mu_p` in its
body but no longer took it as a parameter:

    error: use of undeclared identifier 'mu_p'

The reduction is two copies of `deflate.mere` differing **only** in one
identifier: the position named `p` gives four such errors, the same file
with it named `pos` builds clean. Nothing else changes — same structure,
same nesting, same captures. It is not simply "a name the host also
uses": `main.mere` binds `pos` in thirteen places and that is fine.
Compiled standalone, and imported into a *small* program, `p` is fine
too — so the analysis depends on the importing program.

At least it is loud: a C compile error, not a wrong answer. mgz now calls
the position `pos`, with a comment saying why.

## M9. Native stack, not heap, is what a big input costs — and a Mere program cannot raise its own

Loading a dozen real gems into one process died with SIGSEGV, while any
one of them alone was fine. Two earlier "it must be the stack"
hypotheses in this project had both turned out wrong, so this one was
measured rather than assumed — and it reduced to three programs with no
gems in sight:

```ruby
def m0; 0; end        # ... x N
a = [1, 1, 1, ...]    # N elements
x = 1 + 1 + 1 + ...   # N terms
```

All three crash, and all three crash at the *same* scale: N=4000 runs,
N=8000 segfaults. Not a gem mechanism at all — **program size**. The
interpreter's walk over a statement list, an argument list, or a
left-leaning expression spine is ordinary non-tail recursion, so native
stack use is O(input length), and macOS hands the main thread 8 MB.
Raising `ulimit -s` to 64 MB made all three pass unchanged, which is
what turned a guess into a measurement.

The Ruby-visible half of this was already handled: mere-ruby counts
interpreter depth and raises `SystemStackError` for runaway *Ruby*
recursion. But that counter never sees the parser, so a program that is
merely long dies below it, in C, with no diagnosis.

The pain is that Mere has no answer of its own here. A program cannot
grow its own stack (no thread with a chosen stack size, no `setrlimit`
binding), and the recursion is idiomatic Mere — variant + `match` +
recursion over `list` is *the* shape for a compiler, and the C backend
does not turn it into a loop. So the fix has to live outside the
language, in the link step of whatever embeds it:

```sh
clang -O2 -Wl,-stack_size,0x8000000 mr.c -o mere-ruby
```

128 MB, and the 12-gem batch runs to completion. It is the right fix —
one flag, no code change, and the `SystemStackError` guard still trips
exactly as before for genuine infinite recursion, so nothing is masked.
But it is a fix a Mere user has to already know to reach for, and the
Wasm backend, whose stack is fixed by the host, has no equivalent knob
at all.

## M7. `Map` is a linear-scan assoc array — a dense-int-keyed store degrades O(n²)

Ruby strings are mutable reference types, so the interpreter's `VStr`
became a handle into a global string store. First cut: a `Map` keyed by
`str_of_int id` — the same pattern the array store had used all along.
Result: an eval-heavy test went from 0.21s to 18.8s (90x), with correct
output.

The C backend's `Map` is a linear-scan pair of parallel arrays:
`map_set` scans all existing keys (strcmp each) before appending, and
`map_get` scans from the front. For a store whose keys are dense
integers 0..n-1 that is the worst case twice over — every allocation is
O(n), the total is O(n²), and the strcmp is against keys that only
differ in their last characters. Strings allocate far more often than
arrays (every literal evaluation, every `to_s`, every concat), which is
why the array store never made this visible.

The fix was already in the language: `vec_new`/`vec_push`/`vec_get`/
`vec_set` are O(1) and exactly fit an append-only handle store. Swapping
the store restored the original runtime to the second.

Two findings for Mere: (1) `Map`'s complexity is a silent trap — nothing
in its API distinguishes it from a hash table until a workload leans on
it; a hashed implementation (or a documented complexity note) would
prevent this class of surprise. (2) `vec` covered the need completely —
the pain is discoverability, not capability: the codegen error message
mentioning `vec_len` was how this author learned vectors existed.

## M8. Three different integer widths collide when building a bignum

Implementing arbitrary-precision integers surfaced that Mere's `int` has
*two* widths and a UB trap, all at once:

1. **Runtime is 64-bit.** The generated C uses `int64_t`, so at run time
   `int` is a signed 64-bit value (max 9223372036854775807).
2. **The compiler is 63-bit.** `mere.exe` is OCaml, whose native `int` is
   63-bit. Writing the literal `9223372036854775807` in a `.mere` source
   file makes the compiler's `int_of_string` overflow and abort with
   `Failure("int_of_string")` — you cannot name the runtime maximum
   directly. Work-around: compute it, `4611686018427387903 * 2 + 1`
   (2^62-1 is exactly the OCaml max and is writable).
3. **`clang -O2` deletes overflow checks.** Signed overflow is UB in C, so
   the natural `let r = a + b in if r < 0 then ...overflowed...` is
   optimised away — the compiler assumes it can't happen. Overflow must be
   detected *before* the operation, via bound pre-checks
   (`a > int_max - b`), never after.

None of these is visible until a program needs a value past 2^62. A note
in the Mere docs about the compile-time literal ceiling (and that the
runtime is wider than the compiler's `int`) would save the surprise.
Also, `of` and `signed` are reserved (Mere keyword / C keyword) and can't
be used as `let` names — the C one only surfaces at the clang stage.

## M6. A caught `fail` printed to stderr — FIXED upstream (Mere v0.1.67)

Ruby exceptions have no native counterpart in Mere, so `begin/rescue` is
built on the two primitives that exist: `fail` (raise) and `try_or`
(catch). A `raise` stashes the exception value in a threaded map and calls
`fail` to unwind; `begin` wraps the body in `try_or`, and on catch reads
the exception back and matches it against the rescue clauses. That works —
but every rescued exception printed a stray `fail: ...` line to stderr,
even though the program continued correctly.

The cause was in the C runtime's `__lang_fail_impl`: it `fprintf`-ed the
message to stderr *unconditionally*, before checking whether an active
`try_or` would catch the longjmp. A failure that is about to be caught is
control flow, not an error, and must be silent. The LLVM backend and the
interpreter already did the right thing (check the jmpbuf first, print only
when genuinely uncaught) — so the C backend was both noisy and divergent.
Fixed in Mere v0.1.67 by reordering: longjmp if caught, print only when
about to abort. A satisfying find: using the language's own error
primitive as an exception mechanism is exactly the kind of load a
hand-written test never puts on it.

`retry` and in-place collection mutation are deferred; the exception
semantics themselves (hierarchy matching, ensure ordering, method-level
rescue, `begin` as a value) are complete.

## M4. A bare `Nil` placeholder in a tuple is polymorphic — C codegen only

Small, and a recurrence of a known Mere papercut. M4 threads the "current
block" as a tuple `(has, params, body, cenv)`. A "no block" value is
`(false, Nil, Nil, env)`, and those bare `Nil`s have no local constraint
on their element type — `params` could be any `'a list`. The interpreter
runs it fine (it is polymorphic and never inspected), but the C backend
monomorphizes, and an unconstrained `'a` reaches codegen:
`unsupported C codegen type element: 'a`.

The fix is a one-token annotation at each no-block site:
`(false, (Nil : str list), (Nil : Stmt list), env)`. This is the same
shape as the standing rule that a bare `None` sometimes needs a type
annotation on the compiled backends — a place where inference is happy
but monomorphization needs the type spelled out. Not a milestone
blocker, but worth logging as the pattern keeps returning: a value that
is polymorphic-and-unused in the interpreter must be concrete for C.

Everything else in M4 was clean — blocks as closures fell straight out
of "the block carries its defining env," and threading that env through
the evaluator was the same mechanical tax as `world`. No host-language
change was needed.

## M3. A `Map` cannot live in a record or variant field (region annotations)

Not a bug — a sharp edge in the region system, and the decision it
forced. The object model wants mutable per-object state: an instance
variable table. The natural shape is a value case `VObj of Map[str, Val]`,
or a record `World { ivars: Map[..], classes: Map[..], ... }` bundling
the interpreter's mutable tables.

Neither compiles. Writing a `Map` type in a declaration needs its region
parameter (`Map[__heap, str, Val]`, three arguments, not two), and even
with the region spelled out, `map_new ()`'s inferred region would not
unify with the annotated `__heap` — the checker reports `expected __heap,
got &__heap unit`. A `Map` flows fine as a *bare inferred value* (as it
has since M1), but the moment its type must be *written down* in a field,
the region annotation fights back.

Two consequences shaped M3's design:

1. **Objects are integer handles, not map-carrying values.** `VObj of int`
   is an id; a global object table (`id -> class`) and instance-variable
   table (`"id@name" -> value`) hold the mutable state. This is a
   legitimate representation — many real VMs do exactly this — and it
   keeps `Val` free of an awkward recursive-through-`Map` type.
2. **The interpreter's world is a *tuple* of maps, not a record.** Tuples
   need no type declaration, so `(meths, sup, ocls, ivars)` threads as one
   parameter with none of the annotation trouble, destructured where a
   map is needed. A record would have hit the wall above.

The tax is real: every evaluator function that touches object state
destructures the world tuple, and the whole world threads through the
mutual recursion beside `env`. It is the M1 "no ref cells" story at
scale — mutable interpreter state has to live in maps threaded by hand.
It is the strongest data point yet for either scalar `ref` cells or a
region-annotation ergonomics pass in Mere; noted upstream, not yet a
change. The milestone itself needed no host-language fix.

## M2. A C-backend duplicate-definition bug — FIXED upstream (Mere v0.1.66)

The biggest find so far, and the first bug in Mere's *code generator*
rather than its library. Adding methods (`def`) turned the evaluator into
one mutual-recursion group of eleven functions — `eval_e`, `call_method`,
`run_stmts`, `exec_stmt`, and the rest — threading two maps (locals and
methods) through all of them. It ran correctly under the interpreter, but
the C backend refused to compile: eighteen functions were each emitted
twice, a `redefinition` error from clang.

The cause was in per-instantiation specialization. A polymorphic
function's list of specializations is grown, across resolution passes,
from one concrete arrow type per use site. When a function is used from
many sites, arrows that differ only in a *region type variable* — which
the mangled-name tag erases — pile up as "distinct" specs that all mangle
to the **same** C symbol. The backend then emitted one definition per
spec, and the identical definitions collided.

What made this a satisfying dogfood loop: the interpreter backend matched
`ruby` the whole time, so the logic was provably correct; the bug was
purely in how the *other* backend lowered a large mutual recursion. The
minimal trigger turned out to be emergent — small hand-written groups
would not reproduce it; it took eleven interdependent functions over two
differently-typed maps. Fixed upstream by deduping the spec list by its
emitted C symbol at the single emission point (Mere v0.1.66), with a
reduced eight-function version of this evaluator captured as the
regression test.

## 1. `str_of_float` was not round-trip faithful — FIXED upstream (Mere v0.1.65)

The one real blocker found in M0. Mere formatted floats with 12
significant digits, so:

| expression | ruby prints | mere-ruby could print |
|---|---|---|
| `0.1 + 0.2` | `0.30000000000000004` | `0.3` |
| `1.0 / 3` | `0.3333333333333333` | `0.333333333333` |

Ruby (like modern JS, Python) uses shortest round-trip formatting: the
fewest digits that parse back to the same double. Mere's `str_of_float`
lost information — `float_of_str (str_of_float x)` was not `x` — and
the missing digits cannot be recovered from inside mere-ruby, so float
output parity was blocked on an upstream fix.

**Fixed the same day in Mere v0.1.65**: all four backends now widen from
12 toward 17 significant digits until the string parses back to the same
double. Reading the four implementations side by side for the fix also
surfaced a pre-existing cross-backend divergence (the LLVM helper
rendered whole floats as `100.` where every other backend prints
`100.0`) — fixed in the same slice. The corpus now includes
`puts 0.1 + 0.2` and `puts 1.0 / 3` and matches ruby byte-for-byte.
The dogfood loop working as designed: the first thing the Ruby
interpreter could not print was a bug in the host language, not in the
interpreter.

## 2. Writing a lexer in Mere, tripped by Mere's own lexer

`"{"` is not a string literal in Mere — `{` inside a double-quoted
string starts *string interpolation*, so the character-class check
`str_eq c "{"` in mere-ruby's lexer was a compile error in Mere's lexer. The
fix is `"\{"`. The error message was excellent (it names the escape),
but the collision is memorable: a lexer that could not lex the lexer
being written in it. Any Mere program that processes source code — or
JSON, or templates — will hit this on its first `{`.

## 3. The trailing-expression print

A compiled Mere program prints its final expression's value — a
unit-returning main ends with a stray `()` on stdout, which would break
byte-parity with ruby forever. The established idiom (learned from
mgrep) is to end with `exit (run_cli ())` so the program's value is an
exit code instead of printable output. Fine once known, invisible in
any documentation-shaped place until you diff your output against
another implementation.

## Not pain

- **`let rec ... and ...` mutual recursion** carried the whole
  five-function parser family (`parse_expr` ↔ `parse_bin` ↔
  `parse_unary` ↔ `parse_pow` ↔ `parse_primary`) and the
  `to_s`/`inspect` printer pair without friction.
- **Tuples as parser results** — every parse function returns
  `(node, remaining_tokens)` and destructures with
  `let (e, r) = parse_expr toks in` — read exactly like the OCaml
  original of this pattern.
- **Variants + match for AST and values** are the natural shape for an
  interpreter; the `Tok` / `Expr` / `Stmt` / `Val` types cost four
  declarations and no ceremony.
- Ruby's floor division / sign-of-divisor modulo (`-7 / 2 == -4`,
  `7 % -3 == -2`) took a six-line correction over Mere's C-style
  truncating operators — semantic divergence, but cheap to bridge once
  you know it exists.
