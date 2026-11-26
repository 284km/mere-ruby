# Copied keyword Hash state and invocation lifetime

Feature and resource results below identify accepted runtime
`fac12e8c75aac9574d9957bd1fc84c45f3b2da4b` and main
`89ad241c7cb81c8afa4dc45852b40a0ea9ee2a29`. The separate latest main-integration
section records the new build and complete corpus checks after d4414ac2.
Documentation commits preserve their respective runtime/test inputs.

## Observable behavior and review corrections

A nonempty ruby2_keywords Hash passed through a final splat to an ordinary
positional method, Proc or lambda becomes an independent, unflagged copy.
Native copying preserves subclass, default/default_proc, compare_by_identity
and ivars, bypasses Ruby copy hooks, and drops frozen/singleton state.
Marked methods and Procs preserve their required identity/flag policy.
Method#call prepares arguments at its native boundary.

The Hash ivar-name index belongs to the source owner. A copy neither walks
unrelated ivars nor allocates a per-copy scratch map. Removal and GC retire
index entries. Method#to_proc invokes its captured target through a private
bound-call expression and shared native Method helpers, including supplied
block identity and captured definitions. Public Method#call overrides cannot
intercept that invocation.

Persistent Hash flags and transient call origin have separate lifetimes.
Array literals and both multiple-assignment forms now evaluate value splats
without publishing call origin. Ordinary splats retain an empty flagged Hash;
empty keyword merges contribute no element and evaluate their conversion once.
This fixes the first Minor from the 876ffec8 re-review.

Shared invocation boundaries retire origin on normal and exceptional exits.
Ruby entry hides native-caller origin during inspect/to_s callbacks; native
block callbacks consume it. Explicit yield and actual forwarding protocols
use their argument-preserving entry. This fixes p, print, format("%p") and
Hash#fetch default-block callbacks, including a callback that inspects the
very same Hash as the native caller. No per-builtin cleanup list is added.

Scheduled Threads own startup provenance independently of their creator.
Copy/unflag happens before queueing, so later caller mutation cannot change
queued keywords. Startup bits accompany the existing rooted argument Array.
The original Proc stays rooted until completion and its policy is read after
thread-begin callbacks immediately before binding. Completion retires the
source, arguments and startup block. Corpus controls include deferred startup
across GC, mutation, lambdas/start/fork, marked blocks and deterministic late
marking. No new Ruby container is added for startup provenance.

No Val constructor, unused counting-only object, ObjectSpace exclusion,
upstream test edit, resource-bound change or GC-policy change is introduced.

## Reference and functional comparisons

Clean Ruby 4.0.10: revision `a704b7cd95a42cc0cf5f307137bf3aac0285b915`,
46 default and 38 bundled gems, zero extras, Prism 1.8.2. Compiler
`9dec2ff687a08433247dbdb7729bc19c8522e538`; mgz
`661a01d8bb68f5acd68e3192bd47f081d179c436`.
Use `tools/ref_ruby.sh` to locate and validate the reference. An independently
installed clean 4.0.10 can be selected with `REF_RUBY_BIN`; inspect
Gem::Specification and never install extra gems into Gem.default_dir.

Corpus 987: 127 matching output lines on both engines, normally and with GC
stress 50, including stderr and exit status. The focused plan completes
196 engine comparisons and twelve argument-marker/scratch-scope/GC-mark
checks. It includes main's method-record and ivar-shape regressions, with
MERE_RUBY_MREC_CHECK enabled for method-record/987 controls. Separate
cross-context controls retain every main-matching row; existing required-
keyword error-text and Fiber.yield-origin gaps remain identified follow-ups.

All four complete upstream files use seed 1. No driver limit or new failing
case ID occurs; BOTH / EXTRA stay 0 / 0 throughout. The unchanged test extensions are built separately against
main, head and reference headers.

| File | Evaluator main → head MATCH / RED | VM main → head MATCH / RED |
| --- | --- | --- |
| test_keyword.rb (115) | 115 / 0 → 115 / 0 | 115 / 0 → 115 / 0 |
| test_call.rb (65) | 65 / 0 → 65 / 0 | 65 / 0 → 65 / 0 |
| test_hash.rb (298) | 297 / 1 → 297 / 1 | 297 / 1 → 297 / 1 |
| test_allocation.rb (76) | 8 / 68 → 14 / 62 | 8 / 68 → 14 / 62 |

The Hash RED remains TestHashOnly#test_replace_memory_leak (timeout on both).
Six Proc rest/post/required-rest cases, with and without a supplied block,
become MATCH on both engines. All 76 allocation cases stay in the denominator.

## Remaining allocation differences

All 62 remaining RED cases are classified. Groups overlap test cases.

| Cause | Atomic differences main → head | Affected head tests | Treatment |
| --- | ---: | ---: | --- |
| A+: native-rest/forwarding Arrays | 218 → 218 | 10 | Native storage/GC lifetime are separate PRs; do not hide real Arrays. |
| H+: keyword packets/rest copies | 504 → 504 | 38 | Requires native payloads and ownership representation. |
| A-: CRuby temporary Arrays | 198 → 198 | 40 | Val lists do not need these; do not manufacture them. |
| H-: empty-merger Hashes | 8 → 8 | 4 | Empty double splats need no merger object here. |
| R2K: unused marked-call copies | 28 → 8 | 4 | Keep observable identity; do not create a discarded count-only copy. |

The remaining R2K cases are marked Method/Proc calls using `*r2k_array` and
`*r2k_array1`, with/without a block: expected one temporary Hash, actual zero.
Literal cases now complete and are not an unmeasured timeout category.

## Allocation-file peak attribution and repeated measurement

The previously posted +21% VM family-RSS increase is not reproduced after
integrating current main. Keep all twenty predeclared samples: five alternating
main/head pairs per engine, unchanged file alone, MERE_RUBY_GC_TIGHT=1,
UNITTEST_SEED=1 (upstream --seed=1), no Ruby observer and no forced collection. Every sample
retains its normal-GC case outcomes. No GC tuning or metric replacement is
used to obtain these results.

| Median metric | Evaluator main → head | VM main → head |
| --- | --- | --- |
| Runner OS max RSS, bytes | 413,351,936 → 411,598,848 (-0.424%) | 405,848,064 → 407,814,144 (+0.484%) |
| Largest child OS max RSS, bytes | 312,033,280 → 310,968,320 (-0.341%) | 316,915,712 → 317,046,784 (+0.041%) |
| Sampled simultaneous family max RSS, KiB | 651,584 → 665,264 (+2.099%) | 650,032 → 627,888 (-3.407%) |
| Runner OS peak footprint, bytes | 403,882,872 → 402,064,200 (-0.450%) | 395,461,400 → 397,493,064 (+0.514%) |

The sampled family metric is retained, including evaluator +2.099%; it is
not an exact kernel family highwater. Per-process lifetime maxima must not
be added and called a simultaneous peak. OS compression and short-child
sampling contribute substantial run variation. The sub-percent runner/child
median differences are within the recorded variation, not an improvement claim.

PID-to-child-launch attribution identifies Literal#test_hash_literal's
unchanged 100,000-entry child at 18/20 observed family peaks. Two compressed
baseline samples peak in ProcCall#test_positional_splat_parameter and
MethodCall#test_required_positional_and_keyword_parameter instead. Matching
PIDs avoids a verbose-output race that can label the preceding process with
the next test's header. All twenty largest-child kernel highwaters belong
to the Hash-literal child. In the first evaluator pair, sampled parent RSS
differs by about 2 MiB and sampled child RSS by about 47 MiB, while both child
kernel highwaters are about 311 MB. The coarse sampler catches different
stages of the same short child; it cannot establish a retained-Hash leak.

Five samples per mode/tree, runner OS max RSS in bytes (none discarded):

- evaluator main: 413,351,936, 412,598,272, 418,152,448, 415,023,104, 338,558,976.
- evaluator head: 414,285,824, 405,012,480, 411,598,848, 412,336,128, 407,814,144.
- vm main: 412,942,336, 407,535,616, 405,848,064, 350,437,376, 405,176,320.
- vm head: 326,418,432, 414,826,496, 430,833,664, 407,814,144, 405,258,240.

Five sampled-family peaks in KiB, in the same order:

- evaluator main: 662,896, 673,280, 596,352, 651,584, 498,656.
- evaluator head: 712,816, 589,328, 665,264, 674,432, 627,312.
- vm main: 707,200, 650,032, 734,320, 500,880, 623,296.
- vm head: 489,008, 627,888, 739,248, 646,176, 623,728.

The tight-GC keyword-file control also no longer reproduces the old 46 MB
VM-runner difference: runner max RSS is 319,750,144 → 323,338,240 bytes on
evaluator and 454,492,160 → 455,573,504 bytes on VM. Sampled family peaks
remain 455,024 → 488,928 and 548,064 → 567,456 KiB respectively; these single
samples are disclosed, not silently substituted with runner measurements.

Normal-GC whole-file sampled-family max RSS (single runs, KiB):

| File | Evaluator main → head | VM main → head |
| --- | --- | --- |
| test_keyword.rb | 528,608 → 465,504 | 590,480 → 570,304 |
| test_hash.rb | 392,048 → 421,392 | 332,816 → 361,888 |
| test_allocation.rb | 506,016 → 713,520 | 692,832 → 683,264 |

## Copy slopes and instruction controls

Fresh tight-GC copy controls, OS max RSS bytes at 300,000 → 1,200,000 calls:

| Engine | Main | Head |
| --- | --- | --- |
| evaluator | 88,440,832 → 94,519,296 | 85,753,856 → 90,275,840 |
| vm | 90,701,824 → 91,045,888 | 90,882,048 → 90,046,464 |

No former per-copy map growth recurs. The evaluator grows about 4.5 MB as
calls quadruple (main about 6.1 MB); the VM head decreases slightly.
The unrelated-ivar control retains 50,000 objects with 100,000 ivars, one
String ivar and 20,000 delegated calls:

| Engine | Instructions main → head | RSS bytes main → head |
| --- | --- | --- |
| evaluator | 5,175,485,420 → 5,265,218,047 (+1.73%) | 109,150,208 → 109,019,136 |
| vm | 5,514,041,026 → 5,570,233,762 (+1.02%) | 111,804,416 → 111,673,344 |

Hardware instructions retired, ordinary loops 100k/200k and targeted loops
100k; matrix is unchanged Ruby benchmark/so_matrix.rb:

| Workload | Evaluator main → head | VM main → head |
| --- | --- | --- |
| method_call.rb | 3,535,763,016 → 3,512,779,683 (-0.65%) | 3,816,726,782 → 3,794,629,553 (-0.58%) |
| method_call_200k.rb | 6,125,888,611 → 6,063,397,043 (-1.02%) | 6,758,533,581 → 6,639,583,951 (-1.76%) |
| block_call.rb | 4,380,814,294 → 4,356,065,194 (-0.56%) | 5,252,219,481 → 5,214,960,890 (-0.71%) |
| block_call_200k.rb | 7,833,011,443 → 7,766,227,145 (-0.85%) | 9,581,049,897 → 9,504,020,441 (-0.80%) |
| so_matrix.rb | 199,480,974,155 → 201,352,506,627 (+0.94%) | 213,549,500,590 → 215,393,773,555 (+0.86%) |
| proc_call.rb | 5,170,901,309 → 5,145,594,474 (-0.49%) | 5,365,032,702 → 5,385,512,403 (+0.38%) |
| r2k_method.rb | 5,639,619,291 → 5,601,193,423 (-0.68%) | 6,063,889,654 → 6,019,022,332 (-0.74%) |
| r2k_proc.rb | 5,274,983,010 → 5,301,613,665 (+0.50%) | 5,602,098,107 → 5,629,867,864 (+0.50%) |
| method_object_call.rb | 3,951,910,150 → 3,917,688,896 (-0.87%) | 3,736,457,235 → 3,700,559,995 (-0.96%) |
| method_proc_call.rb | 7,063,851,587 → 7,005,012,121 (-0.83%) | 6,705,227,514 → 6,634,580,520 (-1.05%) |
| method_proc_block.rb | 7,548,067,942 → 8,119,722,176 (+7.57%) | 8,127,120,012 → 8,686,567,328 (+6.88%) |

Ordinary method/block loops improve. Matrix costs about 0.9%; supplied-block
Method proxy costs about 7% for captured-target dispatch and block policy /
identity. The metadata-preserving flagged-copy loop costs about 4–5%.
These correctness costs are disclosed; no work on every call exists solely
to imitate an allocation count.

## Final integration and acceptance

- `run_corpus.sh --both`: **973/973 match**, hash index ON and OFF,
  690.780 s.
- VM corpus: **973 VM / 0 fallback / 0 differences / 0 failures**,
  no fallback-list mismatch, 190.713 s.
- All **ten source gates PASS**, including iv_door and bracket-depth;
  record_hygiene PASS before and after. Header/vendor and CI-timing checks pass.
  Nine text gates use a verified, byte-identical source archive; bracket-depth
  runs against the actual generated C. Binary and source hashes are checked
  throughout the final run.
- Combined #245 source `a7599bfd8d729505c70f4144eecf18c656bee4cb`:
  corpus 987 (127 lines), corpus 993 (22 lines) and fourteen related programs
  match Ruby on both engines normally and under stress 50: **64 engine
  comparisons**. Private forwarded-argument storage and saved keyword origin
  are integrated together. This is focused integration, not full #245 acceptance.

Earlier public 876ffec8 and later private d93/f04 resource results remain
historical measurements, not acceptance of this source. The former material
peak difference is not reproduced against the newly integrated baseline;
the measured sub-percent kernel changes and positive coarse-family deltas
remain disclosed above. Diagnostic binaries and forced-GC observations are
excluded from ordinary O2 acceptance.


Heavy work uses the shared machine queue, at most two Codex heavy runs.
Own corpus sweeps are serial and each allocation-file measurement runs alone.
No full upstream unit suite or Rails cold measurement is run. Code and record
share one push. Automated mere-pr-review-watch inline comments are read after
that push, and the repository owner performs the merge.

The structured [validation record](2026-11-26-codex-allocation-keyword-copies.json) retains all twenty kernel samples, per-case comparisons, input hashes, focus checks and instruction counts without local paths.

## Latest main integration after accepted re-review

The re-review at ec548ffa accepted both Minors, the earlier Majors and the
allocation RSS explanation against main 89ad241c. Those measurements remain
identified by their original runtime; they are not relabeled as new results.

Merged main `d4414ac2c36be3953f2ed7a98a408fd187b7c496` into runtime `4f4694ecbfe92525ce8377630fba056125c1ec9b`. The
Method-call dispatch conflict retains the private shared native entry and
main's frame doors in its moved body. The two moved self accesses now use
fh_self_lv_has / fh_self_lv_get and fh_self_set. A token
comparison of the complete moved Method-call body with main is identical
after excluding this PR's existing argument-origin preparation. No new
allocation policy or counting change is made.

Fresh ordinary O2 validation on that merged runtime:

- corpus `--both`: **978/978 match**, hash index ON and OFF,
  697.076 s. The driver's iv-door and shape-statistics
  preflights run unchanged.
- VM corpus: **978 VM / 0 fallback / 0 differences / 0 failures**,
  no fallback-list mismatch, 228.629 s.
- Corpus 987: all 127 output lines, stderr and exit status match clean Ruby
  4.0.10 in evaluator and VM modes, normally and with GC stress 50. Main's
  831 method-record, 832 frame-restoration and 833 VM-ivar-cache regressions
  also match in those configurations: **16 engine comparisons** total.
- All **ten source gates PASS**, including iv_door and bracket-depth.
  record_hygiene PASS before and after the full sweeps. Header/vendor and
  CI-timing self-tests pass. No full upstream unit suite or Rails cold run.

Binary SHA-256: `3b038941f8ba89c2441d2a5c78349ee292b73bcff21432031c7b87f8decad68b`.
Generated C SHA-256: `bbe562ad5d4a2ed62e7a6b26affbf4360bd517f229552251a8b0c3f78b06c684`.
Compiler 9dec2ff6 and mgz 661a01d8 remain pinned. The reference is the same
independently built, clean Ruby 4.0.10; default/bundled gem audit and source
revision are retained above. These checks use the shared two-run cap and
serial own corpus sweeps. The final documentation-only commit preserves all
runtime/test inputs and the validated binary. Code and record share one push.
