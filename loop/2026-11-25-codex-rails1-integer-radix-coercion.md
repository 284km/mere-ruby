# Integer radix arguments use implicit integer conversion

Integer#to_s rejected non-Integer radix objects instead of calling to_int.
Runtime 3df0302b normalizes non-Integer radix arguments through NUM2LONG and
NUM2INT semantics, including private conversion methods, method_missing,
invalid return types, finite Floats and range errors. Native Integer radix
arguments keep the existing leaf path, which is handled by another stream's
separate width-check work. No bignum source is changed.

Corpus 952 covers small and large receivers, private and inherited to_int,
String/Hash subclasses, Class receivers, method_missing, wrong return types,
float exceptional values and range checks, aliases and retained methods.
It passes on the evaluator and VM against clean Ruby 4.0.10.

Base fd5f54b0, runtime-identical to comparison main a2322f53. Ordinary O2
compiler 9dec2ff6. Reference selected by tools/ref_ruby.sh: Ruby 4.0.10,
revision a704b7cd95a42cc0cf5f307137bf3aac0285b915, 84 default/bundled specs,
no extras, Prism 1.8.2. No reference-default gem installation was performed.

Full corpus --both: 949/949 in both hash modes, 711.128 seconds and
1,206,688 KiB peak family RSS. VM corpus: 949 VM, zero fallback/differences,
181.630 seconds and 1,193,440 KiB. Eight source gates and default record
hygiene pass in the full corpus run.

NumericExtFormattingTest#test_default_to_fs changes from one RED to one
MATCH in both engines; all five selected executions are COMPLETE. Reference
and candidate make 17 assertions; main reaches its 16th assertion and fails.
Native gems explicitly reuse the owned a9e68981 85-package installation;
installing and measured binary digests are retained separately.

Whole CRuby test_integer passes 38 tests / 421552 assertions in all five
executions. Whole test_numeric passes 27 tests / 444 assertions in all five.
These are COMPLETE file results, not selected-case counts.

The first Bignum selection ran zero tests because -test-/integer was absent;
that is recorded as ZERO, not a pass. Building the unmodified three-source
native fixture against each interpreter's headers allows both selected
cases to execute. Reference passes two tests / 13 assertions. Both main and
candidate, on both engines, pass test_to_s and retain the same test_convert
failure: a native 2**32 radix raises ArgumentError instead of RangeError.
This belongs to the separate native-radix range-check work and is not fixed
or hidden here. No native fixture or Bignum test was modified.

Repeated fixed-seed NumericExt and TimeWithZone RSS replays completed
through the shared two-job gate; results are appended below.

Portable evidence:
railstest/framework/records/activesupport-integer-radix-coercion.json.


Final fixed-seed 12345 full Rails replay, three alternating pairs: 206 MATCH / 1 RED to
207 MATCH / 0 RED. All selected files COMPLETE; MISSING/BOTH/UNCONFIRMED/EXTRA zero.
Bounds remain 600 seconds / 2 GiB per family, jobs 2, MT_CPU=0. Native gems explicitly
reuse the owned install made by a9e68981; installing and measuring binary digests are
recorded separately.

Peak family RSS, KiB, three repetitions:

| File | main | candidate |
| --- | --- | --- |
| numeric_ext_test.rb | 337344 / 326256 / 326688 | 332736 / 363072 / 329200 |
| time_with_zone_test.rb | 454720 / 467184 / 461824 | 463984 / 450768 / 458096 |

Samples vary; no stable memory improvement is claimed.
