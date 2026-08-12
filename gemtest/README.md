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

## Where it stands (2026-08-13)

| | loads |
|---|---|
| on what mere-ruby ships | **16 / 29** |
| with a CRuby stdlib on `-I` | **18 / 29** |

Both are single runs of the whole list; the stdlib one takes about five
minutes.

Every remaining failure names its own cause. With a stdlib on `-I`: four are
C extensions (`openssl.so` three times, `socket.so` twice), one is a gem that
is not installed, and the rest — a Rails Railtie method, `TracePoint`, a parse
error in devise, a version constant in rubocop-rails, a nil receiver in sassc
— are recorded in [KNOWN_GAPS.md](../KNOWN_GAPS.md) or still being chased.

Without the stdlib, six of the thirteen failures are only "a pure-Ruby
stdlib library is not here" (`net/protocol`, `ipaddr`, `open-uri`,
`shellwords`, `cgi/escape`). That difference is what the two numbers are
for: the first says how far mere-ruby gets alone, the second what is left
when the libraries it does not ship are handed to it.

That breakdown is the value of the run: it is a list of named work, not a
score.
