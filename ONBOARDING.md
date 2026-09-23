# Onboarding — mere-ruby

A Ruby subset interpreter written in [Mere](https://merelang.org/), in pure
Mere. This is the guide for your first week: what the project is, how to get a
build, where the code lives, and what a change has to survive before it lands.

The other documents are reference; this one is the order to read them in.

---

## 1. What this is, and what "done" means here

mere-ruby reads Ruby source and runs it. It is not a toy: it runs the real
`csv` gem, parses real Ruby files, and gets some way through `bundler`.

**The thing to understand first is how correctness is decided.** There is no
hand-written test suite asserting what mere-ruby *should* do. Instead, every
check runs the same program under mere-ruby and under a real `ruby` and
compares the two **byte for byte**. The reference implementation is the oracle.

That has three consequences you will feel immediately:

1. **The reference is part of the subject.** Every gate sources
   `tools/ref_ruby.sh`, which pins ruby **4.0.6** and refuses any other. A row
   measured against a different release is not comparable with the ones around
   it, and the difference reads as movement in mere-ruby when it is not. If you
   see a row move and you did not touch that area, check which ruby ran.
2. **"It passes" is not the unit.** The unit is "its output is identical".
   A method that returns the right value with a different error message, or the
   right message in a different order, is a DIFF.
3. **Divergences are recorded, not hidden.** `SPEC_STATUS.md` is a checked-in
   scoreboard of where mere-ruby matches CRuby and where it does not — like the
   tags files other alternative implementations keep. It is not a pass/fail
   gate. Adding a row that says DIFF is a *contribution*, because an unmeasured
   area is worse than a measured failing one.

Current record: **2048 of 2948 spec files** byte-identical, 0 CRASH. The suite
has 3821 files; `README.md` has the table of the ones that are not measured and
why, and it adds up.

---

## 2. Set up

You need three things: the Mere compiler, a C compiler, and the pinned ruby.

### The Mere compiler

mere-ruby is written in Mere, so you need `mere` to build it. It lives in a
separate repository and is **not vendored here**.

```sh
git clone git@github.com:merelang/mere.git
cd mere && dune build          # needs OCaml + dune (opam)
```

`tools/build.sh` looks for the compiler in this order: `$MERE`, then
`.mere-compiler/_build/default/bin/mere.exe` (where CI puts it), then `mere` on
`PATH`. Point it at your checkout:

```sh
export MERE=/path/to/mere/_build/default/bin/mere.exe
```

⚠ **This repository develops against the compiler as it is, not against a
release.** CI checks out `merelang/mere` at `main`. That means an upstream
change can turn this repository red, which is the truth of the dependency
rather than a problem with it — and it means a change here sometimes needs a
change there first. It has happened: the work that added the `file_*` metadata
syscalls landed in the compiler before mere-ruby could use it.

### The reference ruby

```sh
. ./tools/ref_ruby.sh    # sets $REF_RUBY_BIN, refuses anything that is not 4.0.6
```

Install 4.0.6 however you manage rubies. ⚠ Do not use `ruby` from `PATH` for
anything you intend to believe — on a typical machine that is a different
version, and a single-file check run against it silently asks a different
question from the sweep. The harness pins the reference itself; you should too.

### Build

```sh
./tools/build.sh           # -O2: emit 41s + clang 112s. THE build for the record.
./tools/build.sh --fast    # -O0: 30s, and the binary runs ~1.7x slower.
./tools/build.sh --cc-only # skip the emit, compile the mr.c that is there
```

⚠ **`--fast` is for shaping a change, never for measuring one.** The sweep
bounds every spec in CPU seconds, so a 1.7x slower binary measures a different
table — files near the budget cross it and the record reports a regression that
is really the optimizer level. Which build made a binary is not visible in the
binary, so `build.sh` writes `.build_mode` and `mspec/scoreboard.sh` **refuses**
to sweep an `-O0` one.

### First run

```sh
./mere-ruby -e 'puts (1..10).select(&:even?).sum'
./mere-ruby script.rb
```

### Platform notes

The build line differs by platform and each flag is load-bearing;
`tools/build.sh` holds both and `README.md` explains each. The one that
surprises people: `-fbracket-depth=1024`. The emitted C nests deeply enough to
exceed mainline clang's default cap of 256, so **a build without it does not
compile**. `tools/bracket_depth_check.sh` bisects clang's own answer and prints
how much room is left, on every CI run.

---

## 3. How the code is organized

~60,000 lines of Mere across eight files. Sizes are a rough guide to where
things are, not a map:

| file | lines | what lives there |
|---|---|---|
| `main.mere` | 32,900 | the evaluator's core, the builtin dispatcher, most class arms |
| `m_eval_leaf.mere` | 11,400 | leaf evaluation, and **the embedded library shims** |
| `m_parse.mere` | 5,900 | lexer and parser |
| `m_driver.mere` | 2,500 | the CLI, and **the core prelude** |
| `m_state.mere` | 2,300 | interpreter state, name tables, the `extern` declarations |
| `m_numeric.mere` | 2,000 | the numeric tower |
| `m_strutil.mere` | 1,600 | string helpers |
| `m_unicode.mere` | 1,300 | case tables, normalization, grapheme breaks |

### The two things that are Ruby, not Mere

This is the most useful fact in this section, and it is not obvious from the
file list. **Parts of mere-ruby are written in Ruby, embedded as Mere string
literals.**

- **Library shims** (`m_eval_leaf.mere`): `require "date"`, `"strscan"`,
  `"digest"`, `"zlib"`, `"stringio"`, `"delegate"`, `"logger"`, `"cgi"` and
  friends are answered by returning Ruby source, which the interpreter then
  evaluates. One `else if str_eq n "<name>" then "<ruby source>"` per library.
- **The core prelude** (`m_driver.mere`, `core_prelude_a` … `_h`): Ruby that
  runs before every program. `File::Stat`, `Time#strftime`, `Dir`'s class
  methods and others live here.

**Work on either as `.rb` first.** Write the Ruby in a scratch file, diff it
against the reference ruby until it is identical, and only then embed it. You
skip a 2.5-minute build per iteration, and the diff is against the oracle
rather than against your reading of the docs.

When you do embed, three things bite:

- **Every `{` must be escaped as `\{`.** Mere reads `{` in a string literal as
  the start of an interpolation — so `h = {}` and `each { |k| ... }` both need
  it, not just `#{`.
- **`\u` is not a valid escape.** Write the character itself.
- **The branch's last string literal needs a trailing `++`** when you append to
  it. Miss it and you get `type error: expected a function, got str`, pointing
  at a line that looks fine.

After embedding, run `mere -c main.mere > /dev/null` to check the *format*
before paying for a full build.

### Where a definition can live

⚠ Mere's visibility boundary is neither the file nor a module — it is the
`let rec ... and ...` **chain**. A definition is visible anywhere in its own
chain, and only *below* it anywhere else. A helper added to the wrong chain is
invisible to its caller (a build error, so you find out); a helper added under
a name that already exists in the same chain is **silently dead** (not an
error, so you do not).

`tools/dup_defs_check.sh` refuses the second. `STRUCTURE.md` — generated by
`python3 tools/gen_structure_map.py` — tells you which chain and which
strongly-connected component a function is in. Read it before moving anything.

### One more thing that will catch you once

A name the dispatcher implements must **also** be in the right name table
(`name_set "filens"`, `"dirns"`, `"ions"`, `"mathns"`, … in `m_state.mere`).
Those tables gate the arm *and* answer `respond_to?`, so a method can compile,
be reachable in the arm, and still raise "undefined method" until its name is
listed. `tools/name_spec_check.sh` catches a tag with no arm and an arm nobody
asks for, but it cannot invent the entry for you.

---

## 4. The documents, and when to read each

| file | read it when |
|---|---|
| `README.md` | now. What is covered, what is not, and why the numbers are what they are |
| `LOOP.md` | before optimizing anything about the dev cycle. What one change costs, every attempt to shorten it, and the ideas that were **measured and rejected** — so you do not re-try them |
| `SPEC_STATUS.md` | picking work. One row per group; generated, never hand-edited |
| `CAUSES.md` | picking work. The same record grouped by *cause* instead of by group |
| `EXAMPLES.md` | diagnosing one file. A recorded row is the FIRST divergence, not the diagnosis |
| `KNOWN_GAPS.md` | before "fixing" something. Divergences that are understood and deliberately unfixed, each saying what it costs and what fixing it would take |
| `MISSING_NAMES.md` | looking for a name-shaped gap. Which core classes are thin |
| `PAIN.md` | curiosity, and when a bug smells like the compiler. What this dogfood surfaced about Mere itself |
| `STRUCTURE.md` | moving or adding a top-level function |

---

## 5. Making a change

### Pick the work by measuring, not by reading

`SPEC_STATUS.md` ranks groups by how many files DIFF. **A row is the FIRST
mismatch in a file, not how many there are** — so a group with 41 DIFF rows may
be 41 separate problems, and a group with 9 may be one root.

Before committing to an area, measure its *deficit*: how many examples in each
file actually fail. Run a spec file through the harness and read the two
tallies it prints:

```sh
./mspec/run_spec.sh /path/to/spec/ruby/core/module/attr_reader_spec.rb
# --- mere-ruby:   pass=15 fail=1 err=0      <- deficit 1: one example
# --- ruby:        pass=16

./mspec/run_spec.sh /path/to/spec/ruby/core/time/new_spec.rb
# --- mere-ruby:   pass=28 fail=170 err=7    <- deficit 185
# --- ruby:        pass=213
```

Both of those are one row in `SPEC_STATUS.md` and they are not the same work.
A file at deficit 1 turns green when you fix one thing; a file at deficit 185
does not, however good the fix.

This is not a nicety. Work has been done here that added three correct methods
and moved the record by zero, because the files those methods unblocked failed
further on as well — the methods were right and the *choice* was not.

### The cycle

```sh
./tools/build.sh --fast                     # shape it
./mere-ruby -e '...'                        # check it by hand against $REF_RUBY_BIN
./tools/build.sh                            # -O2 for anything you will measure
./run_corpus.sh --both                      # the gates (see below), ~75s
./mspec/scoreboard.sh <ruby>/spec/ruby      # the full sweep, ~13 min
```

Roughly: **6 minutes of build and gates, then the sweep.** `LOOP.md` has the
breakdown and the history of getting it there.

### The gates

`./run_corpus.sh --both` is the one to run. It runs 213 corpus programs against
the real ruby with the hash index ON and OFF, plus nine source gates that each
catch something invisible at runtime:

| gate | what it refuses |
|---|---|
| `gc_roots_check.sh` | a `Val`-valued global the collector does not scan |
| `dup_defs_check.sh` | one name defined twice in a chain (the second silently wins) |
| `dead_defs_check.sh` | a top-level function nothing calls |
| `meth_writes_check.sh` | a method-table write that skips the generation bump |
| `name_spec_check.sh` | a name tag with no arm, or an arm nobody asks for |
| `ns_names_check.sh` | a namespace arm and its name list disagreeing |
| `name_len_check.sh` | a length guard that is not its literal's length — which makes the arm unreachable with no build error |
| `rx_caps_check.sh` | a regex capture slot written around `rx_cap_set` |
| `record_hygiene.sh` | a record that names a machine or an operator, or whose tag file and summary disagree |

### Sweeping, and the one rule about it

The sweep rewrites `SPEC_STATUS.md` and every file in `mspec/tags/`.

⚠ **Run one sweep at a time.** Two sweeps overwrite each other's records and
the result is not a smaller measurement, it is a different one. A killed sweep
leaves a tag file it was mid-way through while the summary, written last, still
reads full. `mspec/record_hygiene.sh` reports exactly this — and it has been
ignored, and a wrong conclusion drawn from the numbers beside it. If hygiene
says PARTIAL: restore with `git checkout mspec/ SPEC_STATUS.md` and sweep
again.

`SPEC_JOBS` defaults to 6 workers. The record is byte-identical at 1 and at 6 —
that identity is the check; the speed is the consequence.

### Commit

Commit messages here are **unusually substantial, on purpose**. Look at
`git log` before writing one. The shape is: a subject naming what was learned
rather than what was edited, then the measurement that justified the change,
then — importantly — **what was tried and did not work, and what the first
reading of the evidence got wrong.** Before/after numbers for any row that
moved. Several of the most useful paragraphs in this history are retractions.

There is no PR template and no required reviewer; CI is the gate. Push to a
branch and open a PR, or push to `main` if that is how you are working — but
**do not push a red tree**, because the record is the product.

### CI

Two jobs: `corpus` on macOS (the corpus is a macOS gate deliberately —
mere-ruby reports a darwin `RUBY_PLATFORM` and BSD socket constants everywhere,
so comparing it to a Linux ruby reports real differences that are not defects),
and `build-linux`, which builds with the Linux flags and checks how much room
is left under clang's nesting cap.

---

## 6. Five things that will save you a day

1. **Pin the reference.** `. ./tools/ref_ruby.sh` and use `$REF_RUBY_BIN`.
   A hand-run against `ruby` on `PATH` asks a different question from the sweep.
2. **Never measure an `-O0` build.** The scoreboard refuses it; believe it.
3. **Measure deficit before choosing work.** A row is the first mismatch, not
   the count.
4. **Write embedded Ruby as `.rb` first**, diff against the reference, then
   embed. Then `mere -c main.mere > /dev/null` before a full build.
5. **One sweep at a time**, and if `record_hygiene.sh` complains, stop and fix
   the record before reading any number next to it.

---

## 7. Where to find a first task

`CAUSES.md` groups the record by cause. As of this writing the largest single
kind is `ERROR NoMethodError` at 178 files — a name-shaped gap, which is the
most tractable kind. `MISSING_NAMES.md` says which classes are thin, generated
by asking the reference for its own method lists and then asking this
interpreter for each one.

A good first change is a library shim: they are plain Ruby, they are developed
and verified without a build, and the whole loop fits in an afternoon. The
recent history has several to read as worked examples.
