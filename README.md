# mere-ruby

A Ruby subset interpreter written in [Mere](https://merelang.org/), in
pure Mere. Milestone **M0**: literals, operators with Ruby precedence,
and `puts` — every corpus program prints byte-identical output to the
reference `ruby`.

```sh
mere -c main.mere > mr.c && clang -O2 mr.c -o mere-ruby
./mere-ruby script.rb
./run_corpus.sh     # diff every corpus/*.rb against the real ruby
```

## What M0 covers

- **Literals**: integers, floats, double- and single-quoted strings
  (with Ruby's escape rules for each), `true` / `false` / `nil`, array
  literals, hash literals (`{"a" => 1}`).
- **Operators**, with Ruby's precedence and semantics where they differ
  from C:
  - `**` right-associative and tighter than unary minus on its left
    (`2**3**2 == 512`, `-2**2 == -4`)
  - **floor division and sign-of-divisor modulo** (`-7 / 2 == -4`,
    `-7 % 3 == 2`, `7 % -3 == -2`)
  - **value-returning `&&` / `||`** (`1 && 2` is `2`, `nil || 5` is `5`)
    with short-circuit evaluation
  - **Ruby truthiness**: only `nil` and `false` are falsy — `0` and `""`
    are truthy (`!0` is `false`)
  - mixed int/float arithmetic and comparison (`1 == 1.0` is `true`),
    string `+` / `*` / comparisons, array `+` / `==`
- **`puts`** with Ruby's exact behavior: arrays flatten recursively onto
  separate lines, `nil` prints an empty line, bare `puts` prints an
  empty line, multiple comma-separated arguments.
- Comments, blank lines, expression statements.

## Verification

`run_corpus.sh` runs every program in `corpus/` under the real `ruby`
and under `./mere-ruby` and diffs the output byte-for-byte. The corpus covers
the semantic corners above. A deliberate negative control (lossy float
printing, see PAIN.md) confirms the harness actually detects divergence.

## Why it exists

mere-ruby is a dogfood program for Mere — the start of a long-running probe:
how far can a young ML-family language carry a real dynamic-language
implementation? The interpreter structure (lexer → precedence-climbing
parser → tree-walking evaluator over a value variant) is the classic
functional-language shape, and Mere's variants, pattern matching, and
mutual recursion carry it naturally. What doesn't carry — float
formatting fidelity, for one — gets found, recorded in `PAIN.md`, and
fixed upstream.

Native only in practice (built via the C backend); the interpreter core
is backend-agnostic.
