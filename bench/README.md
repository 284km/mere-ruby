# bench — where the time and the memory actually go

Every harness here is meant to be run against CRuby as well, because a number
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

## `csv.sh`

```
./bench/csv.sh [path/to/mere-ruby]        # ROWS (400), REPS (3, best-of)
```

Can this interpreter run a real gem, and what does it cost? ruby/csv is a good
subject: pure Ruby, no C extension, and it leans on StringScanner, Enumerator,
StringIO and ARGF -- four things an interpreter is easy to get *almost* right.
Six bugs stood between `require "csv"` and this table, and none of them was
about CSV; see the commit that added this file.

The gem is not vendored. The script asks the reference ruby where it loaded
`csv.rb` from and puts that directory on both sides' load path, so the two
sides run byte-identical library code and the interpreter is the only variable.

2026-09-10, csv 3.3.5, ruby 4.0.6, ROWS=400, best of 3:

| | ruby | mere-ruby | |
|---|---|---|---|
| `CSV.parse` plain 401 rows | 0.001 s | 0.212 s | ~200x |
| `CSV.parse` quoted 401 rows | 0.002 s | 5.978 s | ~3000x |
| `CSV.parse headers:` 400 rows | 0.001 s | 0.256 s | ~250x |
| `CSV.parse_line` x400 | 0.009 s | 0.909 s | ~100x |
| `CSV.generate_line` x400 | 0.005 s | 0.888 s | ~180x |

**Read the count column, not just the seconds.** Every line prints the rows,
fields or bytes it produced. Two sides that produced different numbers did
different amounts of work -- and the bug that started this arc was `CSV.parse`
quietly returning every other row, which without the counts reads as a 2x
speedup.

The interesting number is not the 200x, it is the difference between the two
parse rows. Doubling ROWS:

| rows | plain | quoted |
|---|---|---|
| 100 | 0.050 s | 0.628 s |
| 200 | 0.105 s | 1.845 s |
| 400 | 0.209 s | 6.049 s |
| 800 | 0.431 s | 22.002 s |

Plain is **linear** (2.1x, 2.0x, 2.1x). Quoted is **n^1.7 and climbing**
(2.9x, 3.3x, 3.6x), so the gap widens with the file: 12x at 100 rows, 51x at
800. One quoted field switches csv to `parse_quotable_robust`, a different
parser built on regexes and StringScanner rather than String#split -- so the
quoted row is not measuring csv, it is measuring what this interpreter charges
for a regex match and a scanner step. That is where to look before optimising
anything the plain row touches.

## `append.sh`

```
./bench/append.sh [mere-ruby ...]      # REPS (default 3), best-of, alternating
```

Is `String#<<` linear? A Mere `str` is immutable, so an append used to copy
the whole receiver; now it queues beside the string and the next read folds
the queue in (`str_pend` in m_state.mere). Six shapes -- the operator, the
method, a BINARY buffer fed UTF-8 (negotiates every time), an Integer, a read
after every append, and StringIO#write at the end of the stream -- each
checked by its output against ruby, so a DIFF is reported instead of a time.
As of 2026-09-30, -O2, seconds:

| shape | before | after | ruby 4.0.6 |
|---|---|---|---|
| `s << 'ab'` x 20k | 0.207 | 0.160 | 0.105 |
| `s << 'ab'` x 80k | 1.823 | 0.253 | 0.130 |
| `s << 'ab'` x 300k | 24.574 | 0.766 | 0.142 |
| `s.concat('ab')` x 80k | 2.029 | 0.259 | 0.119 |
| `String.new << 'ab'` x 80k | 9.260 | 0.295 | 0.125 |
| `s << 97` x 80k | 1.018 | 0.374 | 0.112 |
| `s << 'ab'; s.size` x 20k | 0.795 | 0.231 | 0.125 |
| `s << 'ab'; s.size` x 80k | 9.387 | 0.585 | 0.136 |
| `io.write('ab')` x 20k | 1.797 | 0.845 | 0.105 |

The 300k build peaked at 6.8 GB RSS before and 306 MB after. What the queue
does NOT change: a read that needs the bytes (`s[i]`, a match, `slice!`) after
every append still folds every time, so `buf << x; buf.slice!(0, k)` costs
what it did -- the same peak footprint too (632 MB vs 633 MB for 50k rounds
on a 4 KB buffer), which is the case a StrBuf-backed queue would have leaked.
StringIO's remaining cost is its Ruby-level #write, linear but ~40 us a call.

## `quad_strings.rb`

```
./mere-ruby bench/quad_strings.rb [n]      # and the same under ruby
```

Thirty-six operations that build a string (or a hash), each at n and 4n. A
ratio near 4 is linear; above 10 is printed `SUPERLINEAR`. On 2026-10-06
(note 290) nine were: `Random#bytes`, `String#reverse`, `#inspect`, `#dump`,
`#scrub`, `#center`, `format("%-*s")`, `Array#to_h` (through `hash_merge`),
and `gsub(str, str)` -- each an `acc ++ piece` per step into an immutable
`str`. `Random.new.bytes(100 MB)` reached 12-16 GB and the 6 GB guard. The
first eight now go through a StrBuf (or a digest Map for `to_h`); `gsub`
goes through the regexp path and its per-match `$~`, which is a separate arc.
`Random#bytes` had a second cost under the first: each Mersenne Twister word
was a map entry keyed `"<gid>:<i>"`, built on every read and write (about
440 bytes per 32-bit draw). With the state in a Vec and the bytes written
into the byte arena, `Random.new.bytes(100 MB)` is 1.5 s and 0.98 GB.

## `regexp.sh`

```
./bench/regexp.sh [path/to/mere-ruby]
```

Thirteen regexp workloads (`bench/regexp_bench.rb`), CPU seconds best of
three against the reference ruby, and the count each answered. Measured
2026-11-05 (Apple silicon, ruby 4.0.9), before and after the engine work of
that day:

| workload | ruby | before | after | what it asks |
|---|---|---|---|---|
| scan_words | 0.04 | 0.13 | 0.10 | `scan(/\w+/)` over 300 KB |
| scan_email | 0.06 | 0.25 | 0.17 | `scan(/[a-z]+@[a-z]+\.com/)` |
| gsub_digits | 0.013 | 0.074 | 0.027 | `gsub(/\d+/, "#")` |
| split_csv | 0.027 | 0.065 | 0.049 | `split(/,/)` |
| match_lines | 0.003 | 0.20 | 0.15 | `=~ /\[ERROR\]/` on 15,000 lines |
| capture_log | 0.014 | 0.060 | 0.044 | five captures per line |
| literal_find | 0.004 | 0.125 | 0.052 | `index(/key_3999/)` in 300 KB |
| anchored | 0.007 | 0.33 | 0.24 | `=~ /\Avalue-\d+\z/` on 20,000 small strings |
| alternation | 0.012 | 0.21 | 0.033 | `scan(/alpha\|gamma\|kappa\|mu/)` |
| dotstar | 0.005 | 0.029 | 0.012 | `scan(/path=(.*)$/)` |
| classes | 0.003 | 0.017 | 0.010 | `scan(/"[^"]*"/)` |
| ci | 0.007 | 0.89 | 0.015 | `scan(/ALPHA\|BETA/i)` |
| nomatch | 0.005 | 0.056 | 0.010 | a pattern that is nowhere |

What changed, in the order it paid:

- **The start set.** A pattern every match of which reads a byte first has a
  set of bytes it can start with; positions whose byte is not in it are
  skipped without running the program (`rxv_fbs`). alternation, ci, nomatch.
- **`/i` on an ASCII character is a class** of its two cases, answered from
  the byte table, not a case swap and a string compare per step.
- **The MatchData is a record until `$~` is read** (`md_force`): `=~` in a
  condition never reads it, and writing its eight ivars and a new string per
  group at every match was most of a small match, and most of what the
  collector then walked.
- **A greedy loop over one character runs in place** (`rxv_span`): the same
  choices in the same order, without dispatching split, body and jump per
  character; and none at all when the byte after the loop is one the body
  never reads (Onigmo makes those possessive).
- **The search before is reused** when the pattern is the same: a scan asks
  once per match, and building the key and eight lookups was more than a
  small match.

Then, the same day, the literal a match must hold (the mean of two runs each,
the 507 binary and this one alternately; the rest did not move):

| workload | ruby | before | after |
|---|---|---|---|
| literal_find | 0.004 | 0.055 | 0.003 |
| scan_email | 0.065 | 0.175 | 0.120 |
| nomatch | 0.005 | 0.010 | 0.001 |

- **The required literal is found first** (`rxq_store`, `rxv_search_lit`):
  the longest run of ASCII characters every match holds, preferring one at a
  bounded distance from the match's start, with the least and most bytes
  before it. The search finds the literal (memchr from the start, a byte loop
  after), and runs the program only at the starts that can reach it. Not for a
  multibyte encoding other than UTF-8, `/i`, or `\G`.
- **String#index on an ASCII string skips the character walks**: the answer
  was a byte offset converted back to characters by copying the prefix and
  counting it, which was most of literal_find after the search.
- **An opening class loop skips its run** (`rxq_lead`, `rxq_next`): when
  `/[a-z]+@/` fails at a letter, it fails at every later letter of that run,
  since the attempts from there are a subset of the ones already tried. Only
  when nothing in the pattern reads where the match started (no backreference,
  condition, call, absent operator or `\G`).

Then, on 2026-11-06, what every statement and call paid (the 508 binary and
this one alternately, best of three; the workloads not listed moved under 10%):

| workload | ruby | before | after |
|---|---|---|---|
| match_lines | 0.003 | 0.130 | 0.047 |
| anchored | 0.007 | 0.210 | 0.088 |
| scan_words | 0.035 | 0.101 | 0.070 |
| capture_log | 0.014 | 0.048 | 0.038 |
| scan_email | 0.058 | 0.114 | 0.100 |
| gsub_digits | 0.013 | 0.026 | 0.022 |

- **A statement no longer pays for what did not change**: setting the current
  file again, summing every store's bytes at the safepoint, and walking the
  undef, alias and singleton tables for names no program touched. With Mere
  0.1.705 (regions are not tallied unless `MERE_REGION_STATS` is set, string
  equality is a length check and `memcmp`), an empty `while` iteration went
  from 1.08 to 0.59 microseconds.
- **The last-search state is a vector of eight slots**, where it was a map of
  eight string keys written at every search.

What is left: match_lines and anchored are the interpreter's loop and call
(13x and 12x ruby's). scan_words is about 30% the VM, 14% entering a search
and 15-20% the collector, so rebuilding the VM would gain at most 1.4x there.

Then, later on 2026-11-06, three smaller costs. The machine was loaded (load
average 8 to 29 from other work), so the seconds moved by more than the
change; instructions retired (`/usr/bin/time -l`, the whole process, so the
setup that builds `text` and `log` is in it) are steadier:

| workload | before | after |
|---|---|---|
| match_lines | 2315M | 1904M |
| anchored | 2844M | 2209M |
| capture_log | 2342M | 1980M |
| scan_words | 2836M | 2400M |
| scan_email | 3614M | 3085M |
| literal_find | 1720M | 1319M |

- **An Integer in a string interpolation is written without the dispatcher**
  (`"value-#{i}"`), when no refinement is active and the program has neither
  prepended to Integer nor defined its own `to_s` on it. anchored's timed loop
  is 20% fewer instructions; most of the setup's drop is this too.
- **The string store's bytes are kept, not walked.** The safepoint asked for
  every string page's block chain at each check; a page's bytes are now
  measured again only after something wrote to it, and the page strings are
  being appended to is measured once a megabyte has been added. A loop that
  keeps making 5 MB strings peaks at 432-570 MB where it peaked at 638-786.
- **The literal prefilter's later searches use memchr too** (Mere 0.1.707's
  `str_index_from`), where only a search from the start did.

The VM was measured again for rebuilding and left: scan_words is 2.0x ruby's
and the VM about 30% of it.

## `recycled_string_pages.rb`

```sh
ruby bench/recycled_string_pages.rb
MERE_RUBY_GC_LOG=1 ./mere-ruby bench/recycled_string_pages.rb
```

The first argument selects temporary allocations (default 100,000); the second
selects explicit collections (default 20). The two calls share an expression,
so the caller's conservative allocation interval includes handles that the
first call has already discarded and collected. The result remains
`[nil, :collected]`; elapsed collection time goes to stderr. With GC logging,
compare the `gc: END live=` counts as well as time. The collector uses the previous sweep's survivor list to skip
collected handles, including holes inside pages that still hold live strings.

Measured on Apple silicon at O2 with Mere `01ed9680` (2026-11-07), using
100,000 temporary allocations and 20 collections, the median of three runs
changed from 0.352 seconds to 0.021 seconds. Peak mark-table entries in these
runs changed from 301,767 to 1,772. Both builds print the same result. These
numbers measure this collector workload, not the duration of the CI workflow.

## `file_read_checks.rb`

```sh
ruby bench/file_read_checks.rb [bytes] [rounds]
./mere-ruby bench/file_read_checks.rb [bytes] [rounds]
```

The defaults create a 1 MiB file of 64-byte lines, perform 1,000 rounds of
`read(0)`, `SEEK_SET`, and `SEEK_CUR`, then read every line with `File.foreach`.
The file size rounds up to a whole line. Timings go to stderr; stdout reports
the final position and next byte, then the line and byte counts. Compare those
outputs with CRuby before comparing times.

Measured on Apple silicon at O2 with Mere `991f299b`, against mere-ruby
`7009a58` (2026-11-07), median seconds from three runs with the defaults:

| workload | before | after | Ruby 4.0.9 |
|---|---:|---:|---:|
| empty reads and seeks | 0.866 | 0.108 | 0.00065 |
| foreach, 16,384 lines | 30.322 | 20.071 | 0.00469 |

The native byte reader no longer loads the file for zero-byte validation or
when pushback supplies all requested bytes. Seeking only reads the file to
find its size for `SEEK_END`; the line reader's seeks over read-ahead bytes
use `SEEK_SET`. Stream checks and flushing remain in place. Positive reads
that need file bytes still load the whole file, so this does not remove all
file-size-dependent work from the line reader.

The foreach runs ranged from 30.3–32.4 seconds before and 15.6–21.2 seconds
after. These are local workload measurements, not an end-to-end CI speedup.

## `buffered_file_writes.rb`

```sh
ruby bench/buffered_file_writes.rb [writes]
./mere-ruby bench/buffered_file_writes.rb [writes]
```

The default performs 16,384 small writes before flushing. Stdout checks the
position, persisted size, and complete contents; elapsed time goes to stderr.
The buffer now appends to the existing String's chunk queue instead of copying
its entire prefix and allocating another String handle for every write.

On Apple silicon at O2 with Mere `991f299b`, against mere-ruby `23ce853`
(2026-11-07), two local runs reduced peak process RSS from 409–526 MiB to
251–252 MiB. Whole-process wall times were 5.12–5.53 seconds before and
4.44–4.62 seconds after. Other validation was running concurrently, so these
wall times are indicative rather than an isolated timing comparison. Ruby
4.0.9 prints the same checks.

A bounded run of Ruby 4.0.9's `fileutils/test_fileutils.rb`, with both test
ordering and `Kernel.srand` fixed to 1, completed with peak RSS of 304 MiB.
Two runs before this change used 1,549–1,793 MiB. All runs reached the same
117 tests and retained the same five existing failures; this measures resource
usage, not full FileUtils compatibility. The CI limits and test inputs are
unchanged.
