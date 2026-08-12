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
| on what mere-ruby ships | **16 / 29** — one run |
| with a CRuby stdlib on `-I` | **18 / 29** — two runs, see below |

The stdlib figure is two runs because `sidekiq-pro` does not finish inside a
batch (`KNOWN_GAPS.md`): gems 1-24 give 14 ok / 10 fail, the four after
sidekiq-pro give 4 ok, and sidekiq-pro itself fails in seconds when run
alone. Counting it as the failure it is, that is 18 loading.

Every remaining failure names its own cause. Four are C extensions
(`socket.so` twice, `openssl.so` twice), one is a gem that is not installed,
and the rest are recorded in [KNOWN_GAPS.md](../KNOWN_GAPS.md) or still being
chased. That breakdown is the value of the run: it is a list of named work,
not a score.
