# A1: check the native Integer radix width

Branch base: current origin/main 0cd831f0. The A1 inventory/refined numeric
table records ruby/test_bignum.rb#test_convert: 0.to_s(2**32) raises
ArgumentError on main instead of Ruby 4.0.10's RangeError.

Before editing, a standalone probe against clean Ruby 4.0.10 and the
unchanged d4e5ba50 O2 main build confirms both signed-32-bit boundaries
are unchecked. A base above signed-64-bit range is silently ignored. The
current branch retains the same unchecked check_radix implementation.
No reference gems are installed.

The signed radix conversion and Process.wait's flags are separate causes.
The reference source process.c uses NUM2UINT for wait flags, so reusing a
signed NUM2INT helper there would be wrong. That unsigned conversion is
recorded for a separate PR. Non-Integer radix coercion is also an existing
gap outside this bounds correction; it is not counted as fixed here.

The correction validates the C int width before the 2..36 radix domain,
and validates a Bignum argument's C long width before conversion to the
machine integer. Ordinary invalid radices retain ArgumentError.

Final ordinary O2 focused comparisons use genuine -test-/integer
extensions built separately outside the reference installation, --seed=1,
and MERE_RUBY_GC_TIGHT=1. Corpus 1117 matches clean Ruby on both engines.
The unchanged ruby/test_bignum.rb test_convert/test_to_s selection passes
2 tests / 13 assertions on the reference and both candidate engines,
versus 2 tests / 14 assertions / one failure on both main d4e5ba50 engines.
No assertion is removed or altered.

| Engine | Main max RSS bytes | Candidate max RSS bytes |
| --- | ---: | ---: |
| Evaluator | 181633024 | 179093504 |
| VM | 179126272 | 181420032 |

The candidate binary SHA-256 is
b8effdbedec538d1a3a38e57c2fd8164ecb18ff76d861a68f879efa6a3d44425,
using Mere 9dec2ff6 and mgz 661a01d8. The generated-C bracket gate passes,
155 required / 1024 supplied. Final sh run_corpus.sh --both passes
917/917 with hash indexing ON and OFF on the evaluator. The separate
MERE_RUBY_VM=1 sh run_corpus.sh --both also passes 917/917, ON and OFF.
Both sweeps complete with exit 0; no partial/ENOSPC attempt is included.
All eight source gates pass: gc_roots, dup_defs, dead_defs, meth_writes,
name_spec, rx_caps, ns_names and name_len. Full record_hygiene, this loop
record's explicit hygiene check and git diff --check pass as well.
No full unit suite or Rails component suite was run.
