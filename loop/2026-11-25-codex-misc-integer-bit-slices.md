# A1: exact Integer bit windows

Branch base: current origin/main d4e5ba50. The cause appears in the
previously recorded A1 numeric table (inventory PR #243, refined in
PR #274). Reference: clean Ruby 4.0.10; no reference gems are installed.

Before editing, the unchanged ruby/test_bignum.rb#test_aref2 was rerun
with --seed=1 and MERE_RUBY_GC_TIGHT=1, using the genuine -test-/integer
extension built separately for reference and Mere:

| Execution | Result | Max RSS bytes |
| --- | --- | ---: |
| Reference | 1 test, 32 assertions, 0 failures | 22577152 |
| Main evaluator | 1 test, 11 assertions, 1 failure | 181010432 |
| Main VM | 1 test, 11 assertions, 1 failure | 181616640 |

The first failure is a negative-width Bignum window: x[5, -1] should be
x >> 5, but the fallback returns only bit 5. Very wide positive windows
also fall back to a single bit. Machine-Integer negative-width windows
use a word-sized shift which cannot promote a large left-shifted result.

No full unit suite or Rails component suite was run. The completed
related comparisons, fixed-seed tight-GC RSS, gates, record hygiene and
both complete corpus sweeps are recorded below.

The correction sends two-argument reads through the exact bit-window
helper for both Integer representations. A negative length is an arithmetic
shift without a mask. A window wholly below bit zero returns zero before
any large left shift. For a very wide positive mask, a nonnegative shifted
value whose bits already fit is returned without constructing the mask.
The obsolete word-sized two-argument helper is removed.

An exploratory, uncommitted small-Integer control found a separate existing
resource-error difference: 16[0, 2**62 - 1] raises NoMemoryError on Ruby,
which constructs the enormous mask, while main already returns 16. This
correction does not claim to emulate that allocation failure. Corpus 1116
uses wide masks with Bignum receivers, as the failing upstream test does;
finite small-Integer and negative-width promotion cases remain covered.


Final O2 focused validation uses the same compiler/mgz pins. Corpus 1116
matches clean Ruby on evaluator and VM. The unchanged Bignum test now
passes 1 test / 32 assertions on both engines, versus main's 11 assertions
and one failure. Candidate max RSS is 180469760 / 182272000 bytes.

The unchanged ruby/test_integer.rb#test_aref also passes all 414780
assertions on reference, main and candidate, on both engines. This covers
machine Integers, word-boundary values, single bits, two-argument windows,
finite/endless/beginless ranges, and negative begins. Runs use --seed=1,
MERE_RUBY_GC_TIGHT=1 and /usr/bin/time -l, one file at a time:

| Engine | Main max RSS bytes | Candidate max RSS bytes |
| --- | ---: | ---: |
| Evaluator | 219840512 | 219545600 |
| VM | 225165312 | 237486080 |


Complete final O2 acceptance:

- sh run_corpus.sh --both: 911/911 pass, hash indexing ON and OFF.
- MERE_RUBY_VM=1 sh run_corpus.sh --both: 911/911 pass, indexing ON/OFF.
- Both fresh commands pass all source gates and full record_hygiene.
- The generated-C bracket-depth gate passes: 155 required / 1024 supplied.
- This completed loop note passes explicit record_hygiene.

The final candidate binary SHA-256 is
17f5178da09b9e644cd112eac1c64798a5661089170e82f1b1ffae2312d953fe.
The baseline is the unchanged d4e5ba50 O2 build; both use Mere 9dec2ff6
and mgz 661a01d8. Corpus, implementation and the full completed record
are included in the first push. No workflow is changed.
