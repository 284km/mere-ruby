# Pain found writing mere-ruby (M0)

A dogfood log: what implementing a Ruby subset interpreter surfaced
about Mere itself.

## 1. `str_of_float` is not round-trip faithful — blocks float parity

The one real blocker found in M0. Mere formats floats with ~12
significant digits, so:

| expression | ruby prints | mere-ruby can print |
|---|---|---|
| `0.1 + 0.2` | `0.30000000000000004` | `0.3` |
| `1.0 / 3` | `0.3333333333333333` | `0.333333333333` |

Ruby (like modern JS, Python) uses shortest round-trip formatting: the
fewest digits that parse back to the same double. Mere's `str_of_float`
loses information — `float_of_str (str_of_float x)` is not `x`. There
is no way to recover the missing digits from inside mere-ruby, so full float
output parity is blocked on an upstream fix (a shortest-round-trip
`str_of_float` across the backends). Until then the corpus restricts
itself to floats whose 12-digit form equals the shortest form, and a
deliberate negative-control file documents the divergence.

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
