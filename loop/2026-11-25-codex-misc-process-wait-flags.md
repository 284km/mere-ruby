# A1: unsigned native wait flags

Branch base: current origin/main a9e68981. The historical A1 inventory in
PR #243 contains TestBignum#test_to_s2, whose third assertion expects
RangeError from Process.wait(1, 2**64). It is a wait flag conversion issue,
separate from Integer radix conversion; the earlier generic C-int label
must not imply signed NUM2INT behavior.

The newest completed main CI report is run 45500110863, source c0a5f15b,
completed 2026-11-25 04:57 UTC, unittest-report artifact 14993455550.
Its reference is Ruby 4.0.10 a704b7cd95. The exact case remains RED in
shard 0, ruby/test_bignum.rb. This report also contains resource-limited
files; its aggregate RED count must not be called assertion failures.

Before editing, clean Ruby 4.0.10 and the existing unchanged d4e5ba50
main control reproduce the missing validation on evaluator and VM. The
current branch retains that same Process.wait implementation. The clean
reference is accessed through tools/ref_ruby.sh; no gems are installed.

Primary reference process.c uses NUM2UINT, assigning the result to an int
before scheduler dispatch. It accepts [-2**31, 2**32-1], unlike NUM2INT,
and has unsigned-long overflow checks and separate Float conversion.
Validation must follow PID conversion and precede scheduler/child lookup.
Existing valid-width, unsupported native flag bits may give EINVAL on
Ruby versus ECHILD in Mere; this distinct OS validation gap is not silently
counted as corrected by range/type checks.

Exact boundary/coercion probes, the unchanged Bignum test, related Process
selections, fixed-seed tight-GC RSS, source gates, record_hygiene and full
corpus sweeps will be recorded after validation. No full unit suite or
Rails component suite is run; no workflow changes are planned.


## Focused correction and unchanged upstream comparisons

Process.wait now validates flags through NUM2UINT-equivalent conversion
after PID conversion and before scheduler dispatch or child lookup. Floats
are checked against the native unsigned-long conversion bounds before
truncation. Integer arguments then obey unsigned-int width with negative
wrapping; wide Bignums retain the unsigned-long error precedence. Public
and private to_int results are checked, and callback exceptions propagate.
waitpid, wait2 and waitpid2 reach the same conversion.

Corpus 1118 matches all 38 output lines, stderr and status on both engines
against clean Ruby 4.0.10 with tight GC. Its scheduler exposes even flags
as signed C ints; Ruby bypasses that hook for WNOHANG. An unrelated
IO::Buffer experimental notice from scheduler setup is disabled explicitly
on both sides; warning behavior is not asserted by this fixture. The
existing unsupported native-OS flag-bit and WNOHANG scheduler differences
are separate from these range/type checks and are not claimed fixed.

Before editing, unchanged test_bignum.rb#test_to_s2 passes 1 test / 5
assertions on the reference and fails on main a9e68981 after 4 assertions.
The candidate now passes all 5 assertions on evaluator and VM. Genuine
-test-/integer extensions are built separately outside the reference
installation. The related unchanged test_process.rb selections are
status_wait, wait_without_arg and wait2: 3 tests / 6 assertions pass on
reference, main and candidate, both engines. Runs use --seed=1 and
MERE_RUBY_GC_TIGHT=1, one file at a time. Max RSS bytes:

| File | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: |
| test_bignum test_to_s2 | 180142080 | 180256768 | 180092928 | 179257344 |
| test_process selections | 190021632 | 187465728 | 206585856 | 206962688 |

The final ordinary O2 candidate SHA-256 is
fdb1d0a2381ec12419dbdff0fb0ce32584b76cba8d7dbaaebc30f85cef8aa514.
The main a9e68981 control uses the same Mere 9dec2ff6 / mgz 661a01d8 pins.
The generated-C bracket gate passes, 155 required / 1024 supplied.
Both complete corpus sweeps pass: `sh run_corpus.sh --both` and
`MERE_RUBY_VM=1 sh run_corpus.sh --both` each match 942/942 programs,
hash index ON and OFF, exit 0. Both runs use the immutable O2 binary above.
The eight source gates, generated-C bracket depth, full record_hygiene,
explicit hygiene for both changed loop records, and git diff --check pass.
A source-only merge preflight with main 85da98fb is clean; it is not a
claim of rebuilt integration acceptance.
No full unit or Rails component suite is run; no workflow is changed.
