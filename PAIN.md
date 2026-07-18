# Pain found writing mere-ruby

A dogfood log: what implementing a Ruby subset interpreter surfaced
about Mere itself.

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
