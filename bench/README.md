# bench — where the time and the memory actually go

Two harnesses, both meant to be run against CRuby as well, because a number
without the reference number is not a measurement.

## `alloc_per_call.sh`

```
./bench/alloc_per_call.sh [path/to/mere-ruby]
```

Peak RSS for 100k / 200k / 400k Ruby method calls, and — for contrast — for
1600 class definitions. As of 2026-08-14:

| program | real | peak RSS |
|---|---|---|
| 100k calls | 0.78s | 1.22 GB |
| 200k calls | 1.54s | 2.44 GB |
| 400k calls | 2.98s | 4.88 GB |
| 1600 classes (3200 defs) | 0.10s | 75 MB |

**~12 KB per method call, never given back**, and it is the *calls* that cost,
not the definitions. That single line explains the rubocop timeout in
KNOWN_GAPS, and it is why a profile of a long load shows half its samples in
`strcmp`: the working set grows without bound, so every string comparison is
a cache miss.

## `require_trace.rb`

```
GEM_HOME=... GEM_PATH=... RUBYGEMS_LIB=<rubygems>/lib \
  mere-ruby -I<stdlib> bench/require_trace.rb <gem>

GEM_HOME=... GEM_PATH=... ruby bench/require_trace.rb <gem>      # the reference
```

Wraps `Kernel#require` and reports **self** time per file — total minus the
requires nested inside it. For `rubocop-ast`: CRuby 0.3s / 50 MB, mere-ruby
6.5s / 5.45 GB.

The `ensure` in the wrapper is the whole trick. A require that RAISES (every
C extension does here) never returns, so without it every second after the
raise is charged to the file that raised — which is how `racc/cparse`, a
require that fails in 2 seconds, once looked like it took 61.
