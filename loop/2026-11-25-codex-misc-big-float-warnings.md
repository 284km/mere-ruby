# A1: warnings when Integer conversion overflows Float

Branch base: current origin/main 4425fcdb, including PR #260. The initial
A1 inventory and refined numeric table identify two RED tests with one
cause: missing Integer-out-of-Float-range warnings. The latest completed
main report used here is run 45500110863, source c0a5f15b, clean reference
Ruby 4.0.10 a704b7cd95; both cases remain RED in shard 0.

| File | Test | Recorded cause |
| --- | --- | --- |
| ruby/test_bignum.rb | test_to_f | Overflowing builtin to_f returns Infinity silently. |
| ruby/test_bignum.rb | test_divide | Integer divided by Float misses the conversion warning. |

The clean reference uses tools/ref_ruby.sh; no reference gems are installed.
Reference bignum.c rb_big2dbl calls rb_warning on an infinite conversion.
That warning is controlled by verbose mode and goes through Warning.warn.
Private big2dbl, used by the accurate Integer fdiv overflow path, differs;
that correction must remain intact. Main's explicit conversion arm still
calls float_of_str directly, without a warning.

Before changing code, reproduce these tests and a warning-callback/operator
matrix against the clean reference and an ordinary O2 main control, on
both engines. Related unchanged test files, fixed-seed tight-GC RSS,
source gates, record_hygiene and both full corpus sweeps will be recorded
with the correction. No full unit or Rails component suite is run.


## Reproduction and implementation

The baseline was advanced to main fd5f54b0 before final acceptance. The
unchanged ruby/test_bignum.rb test_to_f and test_divide selections use
seed 1 and tight GC, with genuine isolated Integer test extensions on both
sides. Ruby 4.0.10 passes 2 tests / 10 assertions; main fails both after
6 assertions; the candidate passes all 10 on evaluator and VM.

Public conversion emits the real Integer-out-of-Float-range warning through
Warning.warn only when verbose is true, with no category keyword. Native
method, alias, Method, Kernel Float, mixed Float arithmetic, formatting,
packing and Math conversion paths use the world-aware conversion boundary.
Private Integer fdiv, exact comparison, Rational ratios and large logarithms
retain their private conversions. A callback exception propagates or is
suppressed according to the actual conversion protocol, without leaving
the soft-conversion state enabled for a later call.

Corpus 1119 contains 100 output rows: 30 operations at nil/false/true
verbosity plus warning-callback exceptions and later conversion controls.
Stdout, stderr and exit status match clean Ruby on both engines. Actual
warning positions come from the current runtime frame, not a test-specific
source substitution. No global world callback or deferred-warning queue is
introduced.

The final ordinary O2 binary, built from integrated fd5f54b0 plus the fix,
has SHA-256 28e789cc33d9ad5097b946e3dd47daf799a8172549281029e0089e5b3d50dde2.
Mere 9dec2ff6 and mgz 661a01d8 remain pinned.

Related-file max RSS bytes, /usr/bin/time -l, seed 1, tight GC:

| File selection | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: |
| test_bignum.rb to_f / divide | 179355648 | 178880512 | 178274304 | 178454528 |

## Ordinary numeric cost

Three alternating main/candidate pairs per workload, ordinary O2, tight GC
and --seed=1. Hardware instructions use the median; RSS is the maximum
across all three runs. No reference/candidate output differs. The same
benchmark source is used on both binaries. Elapsed medians are recorded
as observations on a shared machine, not a significance claim.

| Engine | Workload | Main instructions | Candidate instructions | Change | Main max RSS bytes | Candidate max RSS bytes | Main median seconds | Candidate median seconds |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| eval | integer | 2479886543 | 2482135128 | +0.091% | 73613312 | 73613312 | 0.201942 | 0.205286 |
| eval | float | 3954609987 | 3970224964 | +0.395% | 73646080 | 73596928 | 0.285736 | 0.278656 |
| eval | rational | 2395058164 | 2396169420 | +0.046% | 71663616 | 71663616 | 0.192428 | 0.188244 |
| eval | mixed | 1254371067 | 1264704368 | +0.824% | 71417856 | 71467008 | 0.111581 | 0.120898 |
| eval | to_f | 3052152425 | 3009922795 | -1.384% | 73580544 | 73564160 | 0.221919 | 0.216175 |
| vm | integer | 2252619274 | 2252662143 | +0.002% | 74727424 | 74711040 | 0.174575 | 0.174356 |
| vm | float | 2872684154 | 2873824562 | +0.040% | 74727424 | 74661888 | 0.206670 | 0.210249 |
| vm | rational | 2445932512 | 2443170506 | -0.113% | 72744960 | 72794112 | 0.194057 | 0.190772 |
| vm | mixed | 1255013797 | 1266329734 | +0.902% | 72564736 | 72548352 | 0.112833 | 0.118802 |
| vm | to_f | 3050981747 | 2999864700 | -1.675% | 74727424 | 74678272 | 0.235144 | 0.238449 |

## Completed acceptance

- `sh run_corpus.sh --both`: 949/949, hash index ON and OFF, exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: 949/949, ON and OFF, exit 0.
- gc_roots, dup_defs, dead_defs, meth_writes, name_spec, rx_caps,
  ns_names and name_len: PASS. Generated-C bracket depth: PASS.
- Full and explicit loop record_hygiene, including the updated A1 cause
  inventory, and staged/unstaged diff checks: PASS.

The A1 inventory update records actual selected-case outcomes on main and
transfers native GC/C API/Prism causes without claiming those are fixed by
this conversion correction. It retains exact failing test names and keeps
resource timeouts separate from established leaks. Code, corpus, benchmark
and completed records are committed together. No full unit or Rails
component suite was run; no workflow changed.
