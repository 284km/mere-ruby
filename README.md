# mere-ruby

A Ruby subset interpreter written in [Mere](https://merelang.org/), in
pure Mere. Milestones **M0 + M1**: literals, operators with Ruby
precedence, variables, control flow, and `puts` — every corpus program
(FizzBuzz included) prints byte-identical output to the reference
`ruby`.

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

## What M1 adds

- **Local variables**: assignment and reassignment (`x = x + 1`), read
  anywhere an expression is allowed. The environment is a Mere `Map` —
  whose insertion-ordered semantics happen to match Ruby's hashes, a
  design coincidence this project leans on.
- **Control flow** in the multi-line `... end` form:
  - `if / elsif / else / end`, `unless` (desugared to a negated `if`)
  - `while` and `until` (desugared to a negated `while`), with optional
    `do`
  - `case / when / else / end`, including multi-value `when a, b`
    (Ruby's `===` is plain equality for the value classes in this
    subset)
  - optional `then` after conditions, nested blocks
- Enough for real small programs: the corpus closes with FizzBuzz and a
  float-accumulation loop, both byte-identical to `ruby`.

## What M2 adds

- **Method definitions**: `def name(a, b) ... end` and `def name ... end`,
  called as `name(args)` or (for a no-arg method) bare `name`. Methods
  live in a namespace separate from local variables.
- **`return`**, explicit (with or without a value) and implicit (a
  method's value is its last statement). Early return propagates out of
  nested `if` / `while` / `case` to the method boundary.
- **Recursion**: factorial, Fibonacci, and a recursive sum are in the
  corpus.
- **Flat method scope**: a method body sees only its parameters, not the
  caller's locals — Ruby methods are not closures over their caller. Each
  call runs in a fresh environment, which is both correct and simpler than
  a lexical closure.
- **Statement modifiers**: `return x if cond`, `... unless ...`,
  `... while ...`, `... until ...`.

M2 forced a fix in the host language itself: the evaluator became one
mutual-recursion group of eleven functions threading two maps, and the
Mere C backend emitted several of them twice (a duplicate-definition
build failure). It is fixed upstream in Mere v0.1.66 — see `PAIN.md`.

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
