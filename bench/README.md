# bench — where the time and the memory actually go

Two harnesses, both meant to be run against CRuby as well, because a number
without the reference number is not a measurement.

## `alloc_per_call.sh`

```
./bench/alloc_per_call.sh [path/to/mere-ruby]
```

Peak RSS for 100k / 200k / 400k Ruby method calls, and — for contrast — for
1600 class definitions. As of 2026-08-14 (built with Mere v0.1.258):

| program | real | peak RSS | before v0.1.258 |
|---|---|---|---|
| 100k calls | 0.56s | 0.90 GB | 0.78s / 1.22 GB |
| 200k calls | 1.13s | 1.81 GB | 1.54s / 2.44 GB |
| 400k calls | 2.27s | 3.61 GB | 2.98s / 4.88 GB |
| 1600 classes (3200 defs) | 0.06s | 25 MB | 0.10s / 75 MB |

**~9 KB per method call, never given back**, and it is the *calls* that cost,
not the definitions.

Peak RSS is a coarse instrument: the region allocator doubles its block size,
so RSS is quantized to powers of two and a 10% change can be invisible in it.
To measure a smaller change, count the bytes instead — patch
`__lang_region_alloc` in the generated C to accumulate a total and print it at
exit. That is how the two changes below were told apart from noise, and how
two others (hoisting the `Class#name` key out of the ancestor walk, dropping
two per-frame arrays) were shown to buy nothing and dropped.

## `require_trace.rb`

```
GEM_HOME=... GEM_PATH=... RUBYGEMS_LIB=<rubygems>/lib \
  mere-ruby -I<stdlib> bench/require_trace.rb <gem>

GEM_HOME=... GEM_PATH=... ruby bench/require_trace.rb <gem>      # the reference
```

Wraps `Kernel#require` and reports **self** time per file — total minus the
requires nested inside it. For `rubocop-ast`: CRuby 0.3s / 50 MB, mere-ruby
4.5s / 3.2 GB (was 6.5s / 5.45 GB before Mere v0.1.258).

The `ensure` in the wrapper is the whole trick. A require that RAISES (every
C extension does here) never returns, so without it every second after the
raise is charged to the file that raised — which is how `racc/cparse`, a
require that fails in 2 seconds, once looked like it took 61.

## `alloc_sites.sh`

```
./bench/alloc_sites.sh [path/to/mr.c]
```

`alloc_per_call.sh` says how much memory a call costs; this says what it is made
of, by building a copy of the generated C with a counter and a size histogram
inside the region allocator. As of 2026-08-20:

| program | allocations/call | bytes/call |
|---|---|---|
| `def f; end` called 100k times | **240** | **7377** |
| `100000.times { }` (no call) | 130 | 3722 |
| `def f(a); a + 1; end` | 249 | 8182 |

19 of every 24 allocations are 32 bytes or less. That is the shape any
reclamation work has to move: hundreds of small objects, not one big buffer.

**The generated C is not text.** mere-ruby embeds Ruby sources as string
literals, including bytes that are not valid UTF-8, and its longest line is
397386 bytes: `awk '{print}'` over `mr.c` loses 11 bytes and the copy stops
compiling *at a line nowhere near the edit*. LC_ALL=C does not save it. The
splice here is done with `grep -b` and `head -c` / `tail -c` for that reason,
and anything else that edits generated C should be too.
