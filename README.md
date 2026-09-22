# mere-ruby

A Ruby subset interpreter written in [Mere](https://merelang.org/), in
pure Mere. It runs literals, operators, variables, control flow, methods,
classes and inheritance, blocks and iterators, exceptions, and a broad set of
core methods — every corpus program (FizzBuzz, class hierarchies,
`map`/`select`/`reduce` chains, hashes) prints byte-identical output to the
reference `ruby`. `set`, `pathname` and `digest` are compiled in; the real
`csv` gem is not, and pointed at it with `-I` this parses CSV byte-identically
to ruby 4.0.6 (`bench/csv.sh`).

The milestones below (M0-M6) are how it was built. What it is measured by now
is [ruby/spec](https://github.com/ruby/spec): **1764 of 2498 spec files**
byte-identical to ruby 4.0.6 — every `core` and `language` file the suite has,
plus the libraries this ships — see
[Conformance](#conformance-rubyspec) for what that covers and what it does not.

```sh
./tools/build.sh            # or, by hand, the line below
./tools/build.sh --fast     # -O0: 30s instead of 112s, ~1.7x slower to run.
                            # For shaping a change, NOT for the record -- the
                            # sweep refuses an -O0 binary, because every verdict
                            # in it is bounded in CPU seconds.

mere -c main.mere > mr.c && clang -O2 -Wl,-stack_size,0x20000000 mr.c -o mere-ruby
# That line is macOS's. On Linux all three pieces differ, and none of them was
# written down until CI ran it somewhere else:
#   clang -O2 -fbracket-depth=1024 mr.c -lm -o mere-ruby && ulimit -s 524288
#   -Wl,-stack_size  Mach-O only; the main thread's stack there is `ulimit -s`
#   -fbracket-depth  mainline clang caps nesting at 256, Apple's allows more.
#                    The Ruby prelude is one `"..." ++ "..."` chain and each ++
#                    is a bracket there, so it is split into four `let`s as well.
#                    MEASURED 2026-09-19: the emitted C needs 270, so the flag is
#                    LOAD-BEARING -- a build without it does not compile. It was
#                    240 on 2026-09-10 and that note said the default of 256
#                    would do by sixteen; the sixteen are gone. What grew is the
#                    count of TOP-LEVEL `let`s (each is a nesting level in the
#                    emitted C): m_state.mere went 316 to 361. tools/
#                    bracket_depth_check.sh bisects clang's own answer and
#                    prints both distances on every CI run.
#   -lm              libm is separate there and part of libSystem here
#
# The CORPUS is a macOS gate on purpose. run_corpus.sh diffs this interpreter
# against the ruby on the machine, and this one reports
# RUBY_PLATFORM = "arm64-darwin22" wherever it runs -- its socket constants are
# the BSD ones to match (SOL_SOCKET 65535, AF_INET6 30, SO_REUSEADDR 4). Run it
# beside a Linux ruby and corpus/108_sockets.rb reports a difference that is
# real and is not a defect: two platforms' constants, correctly reported by
# each. Comparing like with like means running where the identity it claims is
# true -- and, for the same reason, beside the ruby VERSION it claims to be.
# main.mere reports `ruby 4.0.6` (tools/ref_ruby.sh names the same version,
# and every gate sources it). The oracle has to be that release: 3.4 changed
# Hash#inspect to put spaces around `=>`, 4.0 prints a Set as `Set[1, 2]`, and
# 3.2.11 stopped warning on a `$=` read where 3.2.2 still warned -- a
# difference inside one minor version. Every axis of the string this reports
# has to match, so CI pins the oracle to exactly 4.0.6 on darwin. None of those
# differences was a defect on either side.
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

## Installing under rbenv

```sh
# Install the build on this machine. The base URL has to point at the tarball
# that was just made -- with the default (a release URL) ruby-build would go
# and download a DIFFERENT one, which is a 404 until that release exists.
./packaging/rbenv/package.sh 0.1.0 "file://$PWD/dist"
rbenv install dist/mere-ruby-0.1.0

# Publishing: the default base URL is the GitHub release for the tag, so
# upload dist/*.tar.gz to it and ship dist/mere-ruby-0.1.0 as the definition.
./packaging/rbenv/package.sh 0.1.0
```

rbenv needs nothing but a `bin/ruby` under `$(rbenv root)/versions/<name>/`, and
the definition is plain shell that ruby-build *sources* — so it carries its own
`build_package_*` function and no patch to ruby-build is required. The version
name deliberately has no platform in it (a `.ruby-version` naming one platform is
wrong on every other machine); the definition picks its tarball from `uname` and
refuses, by name, a platform it has no build for.

What this does **not** get you is `gem install` or `bundle install`. Those need a
C-extension story and a memory footprint this does not have yet — `require
"rubocop"` costs single-digit gigabytes. ruby-build's `mruby` and `picoruby`
definitions ship without RubyGems too, so the bar for being installable is lower
than the bar for being useful to a Gemfile.

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
./run_corpus.sh                                  # 213 programs, byte-for-byte
./run_corpus.sh --both                           # ...with the hash index ON and OFF,
                                                 # running the reference once, not twice
                                                 # (and eight SOURCE gates, see tools/)
./bootstraptest/all.sh <ruby-checkout>           # CRuby's own bootstraptest
./mspec/scoreboard.sh <ruby>/spec/ruby           # every group the record has a row for
./mspec/record_hygiene.sh                        # the records name no machine and no operator
./rgtest/run.sh <rubygems-checkout>              # rubygems' own test files
./parsetest/run.sh <dir> [dir ...]               # can it READ the ruby that exists?
./gemtest/run.sh <gem-home> <rubygems-checkout> [stdlib]   # real gems, loaded
./bundlertest/run.sh <stdlib-dir> <gem-home>     # how far bundler gets, step by step
```

Each harness derives what it needs from the arguments; nothing is left in
`/tmp` between runs. Two of them used to be, and a cleared `/tmp` quietly
took the measurement with it.

`run_corpus.sh` also runs eight SOURCE gates before it runs a program, because
each of them catches a defect that is invisible at runtime -- a rule written
twice, a table nobody reads, a guard that silently disables the arm behind it:

| gate | what it refuses |
|---|---|
| `gc_roots_check.sh` | a `Val`-valued global the collector does not scan |
| `dup_defs_check.sh` | one name defined twice in a chain (the second silently wins) |
| `dead_defs_check.sh` | a top-level function nothing calls |
| `meth_writes_check.sh` | a method-table write that skips the generation bump |
| `name_spec_check.sh` | a `name_set` tag with no arm (an empty table answers false about every name), and an arm nobody asks for |
| `ns_names_check.sh` | a namespace arm and its name list disagreeing -- either a name the call refuses though the arm implements it, or one respond_to? claims and the arm does not |
| `name_len_check.sh` | a length guard that is not its literal's length, which makes the arm UNREACHABLE with no build error |
| `rx_caps_check.sh` | a regex capture slot written around `rx_cap_set` (the next match answers with the last one's group) |
| `bracket_depth_check.sh` | the emitted C outgrowing the nesting the build passes (CI-only: it needs the C) |

`mspec/record_hygiene.sh` is the tenth: it refuses a record that names a
machine or an operator, a tag file whose row count disagrees with its table
row (which is what a killed sweep leaves behind), and a tag file with no table
row at all.

⚠ **The sweep clones the spec tree ONCE, not once per file.** Measured
2026-09-22: a spec file cost 2.71s of which 1.89s was SYS and 0.15s user --
the two interpreters take about 0.1s between them and the rest was copying the
4,333 files of core, language, library, shared and fixtures, which never
change. Ten million clones per sweep, about an hour of syscalls, and enough
filesystem churn to hold `fseventsd` at 100%+ for hours afterwards, which
slowed every other run on the machine by up to 8x. `scoreboard.sh` builds one
tree and hands it to `run_spec.sh` through `SPEC_TREE`; a hand-run of a single
file still gets its own. The full sweep went from ~90 minutes to 30, with every
row of the record byte-identical -- which is the check that the shared tree
changes no answer, and where it would show if a spec ever dirtied it.
[LOOP.md](LOOP.md) has the full breakdown of what a cycle costs, what each
attempt to shorten it was worth, and what is left to try.

⚠ **The sweep's bounds are its own, and the one that matters is CPU time.** A
spec run is limited three ways and [mspec/bounds.sh](mspec/bounds.sh) owns all
three: `SPEC_CPU` (25s) is how much CPU one side may BURN and answers "does
this finish"; `SPEC_WALL` (24× that) is how long one side may EXIST and catches
a process that is blocked rather than slow; the outer bound `scoreboard.sh`
puts on `run_spec.sh` is DERIVED from `SPEC_WALL` so it can never fire first.
Bytes are the third, and the sweep starts `mspec/rss_guard.sh` itself and takes
it down on the way out instead of asking the operator to remember.

A row says WHICH bound the measurements put a file over, never which signal
arrived — two files sit above both the CPU budget and the memory cap, so
"which bound fired" has no stable answer. The numbers behind it go to
`mspec/bound_events.log`, per run, not checked in.

**`SPEC_JOBS` defaults to 6.** The full record is byte-identical at one worker
and at six, which is the check — the speed is the consequence. ⚠ On the ratio:
the eight-group A/B was run back to back and is the load-independent figure
(627.5s against 271.2s, **2.31×**); the full-sweep pair (1829.7s against
646–662s across three samples) was taken hours apart and is the softer claim. Getting there took three fixes, and the last one is the one worth
knowing: a shell sets SIGINT to `SIG_IGN` for a BACKGROUND job and `SIG_IGN`
survives `fork` and `exec`, so every spec under a worker was ignoring SIGINT
while the sequential path was not. [LOOP.md](LOOP.md) has the measurements.

Still run the sweep ALONE. Starting a second harness next to it is what took
this machine down once: bootstraptest extracts a 121k-line generated program,
and the two peaks land together.

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

mere-ruby ships a set of pure-Ruby libraries compiled in (`monitor`,
`stringio`, `strscan`, `set`, `pathname`, `time`, `delegate`, `English`,
`digest`, `securerandom`, `base64`, `shellwords`, `observer`,
`fcntl`, `io/console`, the escape half of `cgi`, …) and those always win over
a file of the same name. ⚠ Each is there because something asked for it and
failed by NAME -- `require "fcntl"` on line four of a spec file took a whole
group down with it -- and each is only as much of the library as can be
answered exactly: `cgi`'s escapers are here and `CGI.new` is not, because a
CGI object in a process that is not a CGI script would have to invent its
environment. Everything else is
searched for on `$LOAD_PATH`, which starts **empty** — mere-ruby has no
stdlib directory of its own to seed it with. `-I` and `RUBYLIB` fill it,
in that order, exactly as in ruby:

```sh
./mere-ruby -I/path/to/ruby/lib/ruby/3.2.0 script.rb
RUBYLIB=/path/to/ruby/lib/ruby/3.2.0 ./mere-ruby script.rb
```

Pointed at a CRuby installation's stdlib, mere-ruby runs a good deal of
it directly — `fileutils` and `uri` parse and load, and `URI.parse`,
`URI.join` and `URI.encode_www_form` answer exactly as ruby 4.0.6 does.
⚠ MEASURED 2026-09-20, and two of the three names this sentence used to carry
were wrong in opposite directions. `uri` did NOT load: a constant defined in a
`class << self` body could not be read from that same body (`uri/common.rb`
line 99 is exactly that shape), which is now fixed and is corpus/205. `racc`
did not load either, and that one is not this interpreter's doing -- in ruby
4.0 racc is a BUNDLED GEM and is no longer under `rubylibdir` at all, so the
example was describing a layout rather than measuring anything. (`shellwords`
used to be here too; it is compiled in now, so the shipped one wins and it
demonstrates nothing about the load path.)

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
and under `./mere-ruby` and diffs the output byte-for-byte: **213 programs,
213 identical** — and again with `MERE_RUBY_NO_HASH_INDEX=1`, so the hash
index cannot hide behind the walk it replaced. The corpus covers the semantic corners above. A deliberate negative control (lossy float
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
target is the `language` and `core` groups, and the C-API (`optional/capi`) is
out of scope. The stdlib (`library`) is IN scope for what this interpreter
actually ships -- see below.

The record covers **2498 spec files** across 103 groups: **1764 MATCH, 694
DIFF, 0 CRASH**, 32 SKIP, 8 SLOW, against ruby 4.0.6. Run with no
directories, the sweep refreshes exactly the groups the table already has, so
the numbers above are reproducible rather than a snapshot -- and every row of
one table is measured by ONE build (`a/sweep_resume.sh` pins it and says so at
the end).

**`core` and `language` are now measured in full**: 2133 of 2133 core files and
80 of 80 language files, every directory the suite has, nested ones included.
`library` is measured for the 16 libraries this ships: 285 of 1516.

⚠ **2498 is not all of ruby/spec** -- the suite has 3821 files, and the number
worth writing down is the one that says what is NOT being asked. Here are the
other 1323, counted so that they add up:

| files | not measured | why |
|---|---|---|
| 1231 | `library/` outside the 16 groups with rows | the libraries this does not ship. A group gets a row when the library is answered, not before |
| 46 | `optional/capi` | out of scope: a C API, and this has no C extensions to answer it with |
| 32 | `command_line` | the executable's flag handling, which `clitest/` measures directly instead |
| 13 | `security` | CVE regressions; four of them need rubygems or optparse |
| 1 | `optional/thread_safety` | one file; it needs the scheduling `core/thread` is still thin on |

A percentage over a surface you chose is worth less than the list of what you
left out, so the list is here and it adds to 3821.

⚠ The last 416 of those were not hard to measure -- they were never ASKED.
`run_spec.sh` clones core, language, shared and fixtures into the tree it runs
in, and once it also cloned library, sixteen library groups had rows. The same
kind of omission hid the rest: the scoreboard takes a nested group name like
`core/file/stat` and turns it into a tag file, and it had simply never been
given one. Adding 32 group names moved 416 files from "unknown" to measured,
157 of them straight to MATCH (`core/process` was 26 of 40 the first time it
was ever run), and it is why the headline MATCH went UP while the percentage
went DOWN. Both are the honest direction.

⚠ **CRASH went 0 -> 10 -> 0.** Measuring core and language in full put ten
aborts in the record, because the surface nobody had measured is where they
were. All ten are closed, and every one was a CYCLE or a REFUSAL that killed
the process instead of raising:

| was | root |
|---|---|
| 4 | `Enumerator::Lazy` materialised its source for every operator the pipeline did not know, so an infinite one ran to 6-17 GB. Sixteen operators are lazy now, buffering ones included |
| 3 | a self-referential structure walked forever. Arrays and hashes were guarded in the PRINTER only: an object holding itself, `Marshal.dump` of a cycle, and `==`/`eql?` between two cycles were each a SIGSEGV. Marshal now writes ruby's object table (`@<index>`), which is also why `[s, s]` writes the string once |
| 2 | `\g<1>`, `\k<-1>` and `\k<01>`: the by-NAME spellings parsed, the numbered ones reached the "undefined group reference" arm and `fail`ed. ⚠ The load-time check validates LENIENTLY, so an unsupported literal passed it and then died in the real parse. A literal this engine cannot compile raises RegexpError now, exactly as `Regexp.new` always did, and one construct no longer costs a whole file |
| 1 | `Enumerator::Product` did not exist |

⚠ These do NOT come from `run_spec.sh <one file>`, which prints DIFF for every
one of them. That verdict answers "do the two outputs differ"; the scoreboard
asks "did it run at all", and mere-ruby printed no tally where ruby ran eleven
examples. When two instruments disagree, find out which question each is
answering before believing the friendlier one.

**Nothing aborts on its own** — CRASH is 0, and the eight SLOW files were
stopped by one of this harness's bounds (six by the CPU budget, one by the
memory cap), not by the interpreter giving up. ⚠ That distinction is now the
definition rather than a convention: a SIGKILL from `mspec/rss_guard.sh` used
to be filed as CRASH, which is a claim about the interpreter, and its row names
the bound instead. So the gap is not "cannot", and a group score reads low for
a reason worth naming rather than for breakage -- real programs (the corpus) match exactly while a value class scores
low on an error message or a frozen-object check. ⚠ Three earlier CRASH rows
have appeared and gone: every one was a NAMED MISSING LIBRARY (`fcntl`, `cgi`,
`io/console`) that the file required on its fourth line, which the scoreboard
reports as a crash because the process dies before it can report.
A whole group can carry a crash for a handful of integers.

Naming the rest is what `CAUSES.md` is for. Grouped by cause, the DIFFs come
down to a bounded number of **kinds**, and the largest single one is
`NoMethodError` (227 files): a name that is not there, which is missing surface
rather than wrong behaviour -- and it grew with the measured surface, because
the groups added most recently (`core/io`, `core/time`, `library/stringio`) are
the ones whose names are thinnest. The next-largest kinds are VALUE mismatches
(`expected "S", got "S"`, `expected N, got N`) and REFUSALS ruby makes and this
does not (`expected ArgumentError to be raised`). Because ruby/spec is laid out
as `core/<class>/<method>_spec.rb`, those files name the absent methods
themselves -- `CAUSES.md` ends with that list, per class, and
[`MISSING_NAMES.md`](MISSING_NAMES.md) asks the same question from the other
side (ruby's own method lists, probed under this interpreter: **185 absent of
1413**).

⚠ A record refreshed only when someone remembers is a claim about the past. One
re-sweep found the table had drifted 3 files from the committed interpreter, so
the invitation to re-run at the bottom of the table is the load-bearing part of
it.

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
