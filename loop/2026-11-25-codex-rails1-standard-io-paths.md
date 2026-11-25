# Standard IO labels for Logger output checks

Logger's output comparison treated STDOUT and STDERR as the same path
because both returned nil. Runtime 45f37ea3 gives the startup streams the
ASCII-8BIT labels <STDIN>, <STDOUT> and <STDERR>. The path getter reads a
real file path first, then this display label. The label has its own scalar
metadata field and cannot become a filename for File#reopen.

The initial prototype used the real-path metadata slot. Full corpus caught
that regression at corpus 333; that negative run is retained locally. The
final version passes both 333 and new 947 on evaluator and VM. Corpus 947
also checks descriptor-created IO objects, the stdlib Logger predicate,
named-file behavior and retention after GC. Existing copied-stream metadata
and path getter String identity differences are outside this change.

Base ecd65075, ordinary O2 compiler 9dec2ff6. Clean reference selected with
tools/ref_ruby.sh: Ruby 4.0.10, revision
a704b7cd95a42cc0cf5f307137bf3aac0285b915, 84 default/bundled specifications,
zero extras and Prism 1.8.2. No gems were installed into the reference.

Final corpus --both: 947/947 with hash index ON and OFF, 688.258 seconds,
maximum family RSS 1,187,664 KiB. VM corpus: 947 VM, zero fallback and zero
differences, 170.652 seconds, maximum family RSS 1,199,104 KiB. All eight
source gates and default record hygiene pass. Bracket depth is 155/1024.
The execution cohort records exact binary and generated-C digests and UTC
times, separately from this documentation update.

The selected LoggerTest#test_log_outputs_to_with_a_broadcast_logger changes
from 0 MATCH / 1 RED to 1 MATCH / 0 RED in both engines. Reference and both
candidate executions are COMPLETE, with three assertions. Each baseline
execution stops at its second assertion with one failure. Native gems reuse
the owned 85-package install made by a9e68981; installer and measured binary
digests are recorded separately. The fixed seed is 12345, with unchanged
600-second / 2-GiB process-family bounds.

Selected-case peak RSS (KiB) is 295,728 to 339,888 on the evaluator and
292,288 to 318,112 on the VM. These are single samples with different
assertion coverage and do not establish a full-file memory comparison.
The owner released the full-file hold. The full IO comparison is recorded above; repeated full Logger RSS is
complete and recorded below. The full IO result remains REPORT_MISMATCH
of the component or the PR's merge criteria.

Portable evidence:
railstest/framework/records/activesupport-standard-io-labels.json.


Final fixed-seed 12345 full Rails replay, three alternating pairs: 31 MATCH / 1 RED to
32 MATCH / 0 RED. All selected files COMPLETE; MISSING/BOTH/UNCONFIRMED/EXTRA zero.
Bounds remain 600 seconds / 2 GiB per family, jobs 2, MT_CPU=0. Native gems explicitly
reuse the owned install made by a9e68981; installing and measuring binary digests are
recorded separately.

Peak family RSS, KiB, three repetitions:

| File | main | candidate |
| --- | --- | --- |
| logger_test.rb | 295680 / 300224 / 292112 | 288416 / 310912 / 354384 |

Samples vary; no stable memory improvement is claimed.

Isolated standard IO inspect/fileno/reopen/path controls pass five tests /
19 assertions in all five executions; all are COMPLETE without a limit.
