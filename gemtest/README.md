# gemtest

Load a fixed list of real, installed gems under mere-ruby and report which
ones come up. The point is not the count: it is that **every failure names
its own cause**, so the list doubles as a work queue.

```sh
./gemtest/run.sh <gem-home> <rubygems-checkout> [stdlib-dir]
```

- `<gem-home>` — a CRuby installation's `gems/<abi>` directory (the tree that
  holds `gems/` and `specifications/`). mere-ruby reads it; it cannot install
  into it, because installing needs TLS. See [KNOWN_GAPS.md](../KNOWN_GAPS.md).
- `<rubygems-checkout>` — a rubygems source checkout; its `lib/` goes on the
  load path so `require "rubygems"` runs the real thing.
- `[stdlib-dir]` — optional. With it, mere-ruby is pointed at that
  installation's pure-Ruby stdlib via `-I`. Without it, mere-ruby runs on the
  libraries it ships, which is the stricter number.

Both numbers are worth keeping: the first says how far mere-ruby gets when it
is allowed to read a CRuby stdlib, the second how far it gets alone.

The gem list is `gems.txt`; point `GEMLIST` at another file to use a different
one. The harness itself carries no paths — everything comes from the arguments
and the environment, so it survives a clean machine. (It did not always: it
lived in /tmp, and a cleared /tmp took the measurement with it.)

**One gem per process** (`load_one.rb`). A gem that crashes the interpreter
outright — a native signal, not a Ruby exception — used to take every gem
after it down with it, and the tally silently shrank to whatever came before
the crash. Twenty-nine startups is the price of a gate that keeps reporting;
a signal shows up as `CRASH <gem>`.

**Every gem is loaded under the reference ruby too**, and a gem ruby cannot
load here either is reported as `SKIP`, not as a failure. Two in the list
(`action_tracer`, `letter_opener_web`) require a Rails application to exist:
CRuby fails them with `uninitialized constant Rails` exactly as mere-ruby
does, and counting those against the interpreter overstated the gap by two.
The denominator in the summary line is the number of gems ruby itself loads.

## Where it stands (2026-08-19)

The denominator is the number of gems the reference ruby itself loads here: 27
of the 29, the other two needing a Rails application to exist.

| | loads |
|---|---|
| on what mere-ruby ships | **17 / 27** |
| with a CRuby stdlib on `-I` | **21 / 27** |

Every remaining failure names its own cause, and with a stdlib on `-I` all six
are boundaries that are already written down: `openssl` (aws-sdk-s3, excon,
fog-aws), `bigdecimal.so` (devise), protobuf (sassc-embedded), and
rubocop-rails past the 120-second budget (a slowdown, not a hang; see
[KNOWN_GAPS.md](../KNOWN_GAPS.md)). Two of those used to stop earlier, at a
character class written out of raw control bytes that the regex engine
rejected — the kind of finding this list exists to produce.

Without the stdlib, ten fail, and the four extra ones are what that stdlib was
answering: seven are a pure-Ruby library that is not here (`net/protocol`,
`ipaddr` ×3, `open-uri`, `shellwords`, `cgi/escape`) and two ask for
`File#fileno`. That difference is what the two numbers are for: the first says
how far mere-ruby gets alone, the second what is left when the libraries it
does not ship are handed to it.

That breakdown is the value of the run: it is a list of named work, not a
score.
