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

## `block_env.sh`

```
./bench/block_env.sh [path/to/mere-ruby]
```

What one BLOCK invocation costs against one `while` iteration, and whether
either is given back. Five programs at 100k / 200k / 400k iterations; the
answer is the slope. Peak RSS is kept as the coarse check but the load-bearing
columns are the region allocator's own counters (`MERE_REGION_STATS=1`):
`default@400k` is bytes ever allocated into the region nothing gives back, and
`stmt_peak` the largest a `region STMT` block grew -- an iterator's enclosing
statement holding per-iteration scratch until the loop ends. Peak RSS alone is
not reproducible at this scale: the same binary on the same program gave 265 MB
and 406 MB in two runs on 2026-09-03.

Measured 2026-09-03, both builds with mere v0.1.409 (the compiler matters:
the same source built with the previous compiler read 1617 B/iter for
`times_call`, so a comparison is only between binaries built by the same one):

| program | before (B/iter) | after | default@400k before | after | stmt_peak before | after |
|---|---|---|---|---|---|---|
| while_bare | 80 | 64 | 41.0 MB | 26.6 MB | 1 MB | 1 MB |
| while_call | 519 | 300 | 104.4 MB | 40.4 MB | 1 MB | 1 MB |
| times_bare | 533 | 200 | 190.5 MB | 20.2 MB | 267 MB | 66 MB |
| times_call | 1121 | 317 | 437.6 MB | 69.0 MB | 267 MB | 66 MB |
| lambda_call | 1299 | 248 | -- | 39.4 MB | 267 MB | 66 MB |

Three changes, each named by a measurement rather than a guess:

1. **Block envs come from the frame pool** (`blk_env_get` / `blk_env_put`).
   A block invocation used to `lv_child` a fresh Map into the default region
   and leave a permanent `lv_up` entry; a method call had been taking its frame
   from `frame_pool` since v0.1.300. The pool is also the on-stack registry
   that pruning `lv_up` was waiting for: `lv_up` after a 400k loop is 0 (was
   400000), `pool_news` is 2. Envs a closure captured are left alone
   (`blk_kept` counts them).
2. **A region per block invocation** (`region BLK`), the same shape as
   `region MCALL`. Where the region starts was found by measuring, not
   reasoning: around the body alone it moved nothing; adding parameter binding
   halved `stmt_peak`; putting the `try_or` itself inside (so the closure that
   enters the body is allocated in the region too) halved it again. The env is
   the one thing born outside -- it comes from the pool and may be captured.
3. **Scalar bookkeeping stopped being boxed.** `def_maps.sh` attributed 260 of
   the remaining 302 MB of default-region growth to eleven str->Val maps written
   once per statement or per call (`cur_pos_s` 73 MB, `struct_ctr` 37,
   `flow_sig` 34, `call_files_s` 31, `cur_pos` 24, `live_frames` 18,
   `call_lines` 12, ...): every overwrite of a Val copies a new box into the
   default region and orphans the last one. Counters became int maps (an int
   overwrite allocates nothing); the str->str ones write only when the text
   changes (`map_set_s`); run_block's ok-flag became a saved/restored int.

On a real gem load (`require "rubocop-ast"`, 156 files, `bench/require_trace.rb`),
the same changes read: peak RSS 818 -> 626 MB (-24%), default-region bytes
196 -> 160 MB (-18%), `lv_up` 59,589 -> 928, time 6.5 -> 6.2 s (CRuby: 0.3 s,
52 MB). A gem load is mostly definitions, so the block-loop win shrinks to a
fifth there. (Measured against the same source with only the GC-root fix of
§30 applied, because the unfixed base stopped that load with
`Illformed requirement [""]`.)

What is left, in order: `stmt_peak` 66 MB = ~165 B per invocation still held
by the iterator's enclosing statement (the argument cons cell the iterator
builds before calling run_block, the Flow copied out of BLK, the two
`str_of_int` keys of blk_env_get/put) -- a `while` gets a `region ITER` per
iteration, a block loop does not, so a single 10M-iteration `each` still holds
~1.6 GB until it returns. Freeing that needs the region in the ITERATOR (one
per `run_block` call site, of which there are hundreds) or an int-keyed lv_up. Then the default residue: `lv_up`'s key churn (15 B per
invocation) and the top-level env's assignment orphans (`<not a global map>`
in def_maps.sh, ~30 B per top-level assignment).

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
