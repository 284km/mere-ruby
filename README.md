# mere-ruby

A Ruby subset interpreter written in [Mere](https://merelang.org/), in
pure Mere. Through milestone **M5** it runs literals, operators, variables,
control flow, methods, classes and inheritance, blocks and iterators, and a
broad set of core methods — every corpus program (FizzBuzz, class
hierarchies, `map`/`select`/`reduce` chains, hashes) prints byte-identical
output to the reference `ruby`.

```sh
mere -c main.mere > mr.c && clang -O2 -Wl,-stack_size,0x20000000 mr.c -o mere-ruby
./mere-ruby script.rb
./run_corpus.sh     # diff every corpus/*.rb against the real ruby
./clitest/run.sh    # diff the driver's argv handling against the real ruby
```

The driver takes the shapes ruby's does:

```sh
mere-ruby script.rb a b      # ARGV = ["a", "b"]
mere-ruby -e 'puts 1+1'      # repeated -e are lines of ONE program
mere-ruby -I lib script.rb   # -Idir or -I dir; flags AFTER the script are its own
echo 'puts 1' | mere-ruby -  # `-` is stdin; a BARE mere-ruby prints usage
mere-ruby -v                 # the same string RUBY_DESCRIPTION returns
mere-ruby -h
```

An unrecognised option is an error, not a filename. A bare `mere-ruby` does
not read stdin though ruby does — see [KNOWN_GAPS.md](KNOWN_GAPS.md).

`-stack_size` is not optional. Parsing and evaluating recurse over the
statement list, so native stack use grows with program size; on the
default 8 MB main-thread stack a program of roughly 8000 statements
segfaults before the interpreter's own `SystemStackError` guard can see
it. 512 MB was measured, not guessed: at that size both plain recursion
and a heavy frame (block, hash, string, begin/rescue) reach 100 000
native frames. The interpreter's own guard sits at 15 000 — deep enough
for rubocop-ast's recursive-descent pattern compiler, which needs more
than 10 000, and low enough that a RUNAWAY recursion trips the catchable
`SystemStackError` before it has committed much of that stack, which is
what a batch of programs in one process depends on. See
[PAIN.md](PAIN.md) §M9.

Divergences that are understood and deliberately unfixed are tracked in
[KNOWN_GAPS.md](KNOWN_GAPS.md), with what each costs and what fixing it
would take — separately from what nobody has looked at yet.

## Gates

Every change is checked against the reference `ruby` before it lands:

```sh
./run_corpus.sh                                  # 162 programs, byte-for-byte
./bootstraptest/all.sh <ruby-checkout>           # CRuby's own bootstraptest
./mspec/scoreboard.sh <ruby>/spec/ruby           # every group the record has a row for
./rgtest/run.sh <rubygems-checkout>              # rubygems' own test files
./parsetest/run.sh <dir> [dir ...]               # can it READ the ruby that exists?
./gemtest/run.sh <gem-home> <rubygems-checkout> [stdlib]   # real gems, loaded
./bundlertest/run.sh <stdlib-dir> <gem-home>     # how far bundler gets, step by step
```

Each harness derives what it needs from the arguments; nothing is left in
`/tmp` between runs. Two of them used to be, and a cleared `/tmp` quietly
took the measurement with it.

`MERE_RUBY_STACKTRACE=1` makes the recursion guard dump the innermost call
names before it raises. mere-ruby keeps no backtrace, so this is the only
view into a runaway recursion — it is what named rubocop's as an eight-frame
cycle through a fallback visitor, and from there the cause (a `method_added`
hook that never fired) was one test away.

## Vendored packages

`zlib` is a C extension in CRuby. Here it is [mgz](https://github.com/284km/mgz)
— gzip in pure Mere — vendored under `.mere_modules/` and imported, so a
checkout needs its submodule:

```sh
git clone --recurse-submodules <this repo>
# or, in an existing checkout:
git submodule update --init
```

That gives you `Zlib.crc32` (including the seeded form a PNG chunk
needs), `Zlib.adler32`, `Zlib::Inflate.inflate` and
`Zlib::Deflate.deflate` — real dynamic-Huffman compression, not stored
blocks. Verified both directions against CRuby: mere-ruby reads what the
system zlib writes, and the system zlib reads what mere-ruby writes.

## The load path

mere-ruby ships a handful of pure-Ruby libraries compiled in (`monitor`,
`stringio`, `strscan`, `set`, `pathname`, `time`, `delegate`, `English`,
…) and those always win over a file of the same name. Everything else is
searched for on `$LOAD_PATH`, which starts **empty** — mere-ruby has no
stdlib directory of its own to seed it with. `-I` and `RUBYLIB` fill it,
in that order, exactly as in ruby:

```sh
./mere-ruby -I/path/to/ruby/lib/ruby/3.2.0 script.rb
RUBYLIB=/path/to/ruby/lib/ruby/3.2.0 ./mere-ruby script.rb
```

Pointed at a CRuby installation's stdlib, mere-ruby runs a good deal of
it directly — `shellwords`, `fileutils`, `racc`, `uri` all parse and
load.

A C extension is not automatically out of reach, but it has to be
answered rather than found. `digest`, `date` and `etc` ship as Ruby
source, `zlib`'s compression comes from a vendored Mere package (above)
with its stream classes shipped as Ruby source over it, and `rbconfig`,
`thread` and `fiber` are satisfied without a file (`fiber.so` is loaded
before any Ruby runs in CRuby 3.x, so `require "fiber"` returns false
there too). `socket` is answered by the interpreter itself: `TCPSocket`,
`TCPServer` and the rest are Ruby source over Mere's own socket FFI, so a
program here really does connect, listen, accept and exchange bytes —
zero bytes included. UDP and UNIX sockets exist but refuse
(`NotImplementedError`), because a socket library that silently does
nothing moves a failure away from its cause. `openssl` is not answered: a
TLS stack is a binding to a third-party C library, deliberately out of
scope, and linking one would make the (native-only) dependency reach the
Wasm build too.

RubyGems and Bundler are the ones that matter, because everything else is
loaded through them: pointed at a CRuby stdlib, `require "rubygems"` works,
`require "bundler"` works, a real `Gemfile` evaluates, and **`Bundler.setup`
answers what ruby answers** — resolving the dependencies and setting up the load
paths. `bundlertest/run.sh` compares that step by step against the reference and
has no recorded divergence left; the walls it worked through, in order, were
thor's `caller[1]`, comparison through a user `<=>`, `module_function`'s scope,
an exception that kept neither class nor message, `rescue *[]` swallowing
everything, an `ensure` body consuming the exception it ran under, and
`File.open` refusing the `Pathname` bundler writes the lockfile through.

Against a sample of 29 installed gems — of which the reference ruby itself
loads **27** here, two needing a Rails application to exist —
`gemtest/run.sh` loads **21** with a CRuby stdlib on `-I` and **17** on
what mere-ruby ships. With the stdlib, every one of the six that do not is a
boundary this README already names: `openssl` three times (aws-sdk-s3, excon,
fog-aws), `bigdecimal.so` once (devise, which loads the whole activesupport /
i18n / concurrent-ruby stack before it gets there), protobuf once
(sassc-embedded), and rubocop-rails running past the gate's 120-second budget
while loading rubocop's ~600 cop files (see [KNOWN_GAPS.md](KNOWN_GAPS.md) —
it is a slowdown, not a hang; it reads unicode-display_width's gzipped
`Marshal` index and compiles rubocop-ast's node patterns on the way).

Without a stdlib on `-I`, ten fail, and the four extra ones are what that
stdlib was answering: seven of the ten are a pure-Ruby library that is simply
not here (`net/protocol`, `ipaddr` ×3, `open-uri`, `shellwords`, `cgi/escape`)
and two ask for `File#fileno`. That difference is what the two numbers are
for.

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
  locals — the counterpoint to M2's flat method scope. Its params and the
  locals it first assigns are block-local, living in a per-invocation frame
  chained to that scope, so each iteration gets its own binding and a
  `lambda` created inside the block keeps them after the block returns.
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
match, each row carrying WHY it does not).

`./mspec/causes.sh` then groups those rows by cause and writes
[`CAUSES.md`](CAUSES.md). That is the number worth acting on: the table says how
many files disagree, and this says how many NAMES they come down to. It reads
the tags files only, so the bucket key can be retuned without re-sweeping. Those tag files are the honest, checked-in record of the gap — the
same idea as the tags/filter files every other implementation keeps. Passing
100% is a non-goal (only MRI does, because the specs are derived from it); the
target is the `language` and `core` groups, with `command_line` low-priority
and the C-API (`optional/capi`) and stdlib (`library`) out of scope.

The record covers **1054 spec files** across 26 groups: **439 MATCH, 587 DIFF,
22 CRASH**, 5 SKIP, 1 SLOW. Run with no directories, the sweep refreshes exactly
the groups the table already has, so the numbers above are reproducible rather
than a snapshot.

**97% of the files run on both sides** (MATCH + DIFF); 22 abort. So the gap is
mostly not "cannot", and a group score reads low for a reason worth naming
rather than for breakage -- real programs (the corpus) match exactly while a
value class scores low on an error message or a frozen-object check.

Naming it is what `CAUSES.md` is for. Grouped by cause, the 605 DIFFs come down
to a bounded number of **kinds**, and the two largest are `NoMethodError` and
`NameError`: a third of the gap is a name that is not there, which is
missing surface rather than wrong behaviour. Because ruby/spec is laid out as
`core/<class>/<method>_spec.rb`, those files name the absent methods
themselves -- `CAUSES.md` ends with that list, per class.

⚠ Re-sweeping also showed the previous table had drifted 3 files from the
committed interpreter: two `language` files and one `core/queue` file were
recorded as MATCH and fail under the binary they were supposed to describe (and
under the one before it). A record refreshed only when someone remembers is a
claim about the past, so the invitation to re-run at the bottom of the table is
the load-bearing part of it.

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
