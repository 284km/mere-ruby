# mere-ruby

A Ruby subset interpreter written in [Mere](https://merelang.org/), in
pure Mere. Through milestone **M5** it runs literals, operators, variables,
control flow, methods, classes and inheritance, blocks and iterators, and a
broad set of core methods — every corpus program (FizzBuzz, class
hierarchies, `map`/`select`/`reduce` chains, hashes) prints byte-identical
output to the reference `ruby`.

```sh
mere -c main.mere > mr.c && clang -O2 mr.c -o mere-ruby
./mere-ruby script.rb
./run_corpus.sh     # diff every corpus/*.rb against the real ruby
```

## In the browser

mere-ruby also compiles straight to WebAssembly, so it runs Ruby entirely
client-side — no server, no filesystem. The playground under [`docs/`](docs/)
is a single page that fetches `mere-ruby.wasm`, hands the editor's source to
`run_cli` (via a `read_file` sentinel), and shows the output:

```sh
mere -w main.mere | wat2wasm --enable-tail-call - -o docs/mere-ruby.wasm
# or: docs/build.sh
cd docs && python3 -m http.server   # then open http://localhost:8000/
```

This needs Mere **v0.1.127+**, whose Wasm backend widened `int` to 64 bits —
without it `1234567890123 + 1` (and any Ruby integer past 2³¹) could not run
in the browser.

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

## What M3 adds — the object model

- **Classes**: `class Name ... end`, `class Name < Super ... end`,
  instance methods via `def` inside the class body.
- **Instances**: `Name.new(args)` allocates an object and runs
  `initialize`; `@ivar` reads and writes instance variables; `self` is
  the receiver.
- **Method dispatch** walks the ancestor chain (`obj.method(args)`,
  and no-arg `obj.method`), so subclasses override and inherit. A method
  can call a sibling method with an implicit `self`.
- **`attr_accessor` / `attr_reader` / `attr_writer`** synthesize getters
  and setters; `obj.attr = value` calls the setter.
- **Symbols** (`:name`) and a few primitive methods (`to_s`, `to_i`,
  `to_f`, `size` / `length`, `abs`) — a small preview of M5, since a
  class's `to_s` immediately needs `@x.to_s`.

Objects are represented as integer handles into the interpreter's world
(a bundle of maps: class table, superclass links, object classes,
instance variables). See `PAIN.md` for why that shape, and why the
world is a *tuple* of maps rather than a record.

## What M4 adds — blocks and iterators

- **Blocks** (`{ |x| ... }` and `do |x| ... end`) as true closures: a
  block captures its defining scope and reads and mutates the enclosing
  locals — the counterpoint to M2's flat method scope.
- **Built-in iterators** taking a block: `each`, `map`, `select`,
  `each_with_index` on arrays; `times` and `upto` on integers.
- **Ranges**: `1..5` (inclusive) and `1...5` (exclusive), with `.each`,
  `.map`, `.to_a`.
- **`yield`**, which calls the block passed to the current method —
  including nested cases (a method that yields from inside `@xs.each { |n|
  yield(n) }`) and implicit-`self` block calls (`each { ... }` inside a
  method calling `self.each`).

## What M5 adds — core methods (breadth)

All non-mutating, matching Ruby's results:

- **Indexing**: `arr[i]`, `str[i]`, `hash[k]`, with negative indices.
- **String**: `upcase`, `downcase`, `capitalize`, `reverse`, `strip`,
  `chars`, `split`, `include?`, `start_with?`, `end_with?`, `empty?`.
- **Array**: `first`, `last`, `sort`, `uniq`, `min`, `max`, `sum`,
  `index`, `count`, `join`, `reverse`, `include?`, plus block forms
  `reduce` / `inject`, `reject`, `count`.
- **Hash**: `keys`, `values`, `size`, `[]`, `key?` / `has_key?`,
  `include?`, `each { |k, v| }`, `select { |k, v| }`, `empty?`.
- **Integer**: `even?`, `odd?`, `zero?`, `succ`, `pred`, `abs`.
- **Universal**: `class`, `nil?`, `inspect`, `to_s`, `to_i`, `to_f`,
  `to_a`, `size` / `length`.

Method names ending in `?` or `!` lex correctly, and method chains
continue after a block (`arr.map { |x| x * 2 }.sum`). In-place mutation
(`<<`, `push`, `arr[i] = v`) is deferred to a later milestone; the corpus
builds collections functionally.

## What M6 adds — exceptions

- **`raise`** with a message, a class, or a class and message.
- **`begin` / `rescue` / `else` / `ensure` / `end`**, `rescue Class => e`,
  multiple `rescue` clauses, a bare `rescue` (catches `StandardError`),
  method-level rescue (`def f ... rescue ... end`), and `begin` used as a
  value (`x = begin ... end`).
- **Exception class hierarchy**: built-in `RuntimeError` / `ArgumentError`
  / `ZeroDivisionError` / … `< StandardError < Exception`; user exceptions
  extend it (`class MyError < StandardError`). `rescue` matches up the
  chain. Integer division by zero raises a real `ZeroDivisionError`.
- `e.message` / `e.class`. (`retry` is deferred.)

This is the last piece of the **G1 subset**: 40 corpus programs — FizzBuzz,
class hierarchies, iterator chains, hashes, and exception flows — all match
the reference `ruby` byte-for-byte, on both the interpreter and the
C backend.

## Verification

`run_corpus.sh` runs every program in `corpus/` under the real `ruby`
and under `./mere-ruby` and diffs the output byte-for-byte. The corpus covers
the semantic corners above. A deliberate negative control (lossy float
printing, see PAIN.md) confirms the harness actually detects divergence.

## Conformance (ruby/spec)

Ruby has no normative written spec — CRuby (MRI) is the definition, and
[ruby/spec](https://github.com/ruby/spec) is the community's executable
conformance suite that the other alternative implementations (JRuby,
TruffleRuby, Opal, Artichoke) target. mere-ruby measures against it too.

`mspec/scoreboard.sh` sweeps ruby/spec directories, runs each spec file under
both mere-ruby and `ruby` through a minimal mspec shim, and compares
byte-for-byte. It writes `SPEC_STATUS.md` (a per-group MATCH / DIFF / CRASH /
SKIP table) and `mspec/tags/*.txt` (the per-file list of what does *not*
match). Those tag files are the honest, checked-in record of the gap — the
same idea as the tags/filter files every other implementation keeps. Passing
100% is a non-goal (only MRI does, because the specs are derived from it); the
target is the `language` and `core` groups, with `command_line` low-priority
and the C-API (`optional/capi`) and stdlib (`library`) out of scope.

A DIFF is usually fidelity, not breakage: real programs (the corpus) match
exactly while a value class scores low on ruby/spec because of an error
message, a frozen-object check, or an exotic coercion path.

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
