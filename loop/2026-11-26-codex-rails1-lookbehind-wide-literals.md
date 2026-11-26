# Lookbehind character widths

ActiveSupport titleize capitalized letters after apostrophes incorrectly because
lookbehind widths mixed byte counts with character positions. This change restores Ruby-
compatible titleization and lookbehind matching.

Measure lookbehind widths and candidate positions in whole characters, including multi-
codepoint Unicode escape lists, exact-once byte repetitions and six-byte CESU-8
literals. Positive plain alternatives preserve pattern order/capture backtracking; calls
and backreferences retain their shared trial range. Known legacy decoders step back from
character boundaries without rescanning the whole prefix at every match.

Corpus 949 covers titleize, alternatives/captures/subroutines, legacy subject
boundaries, and positive/negative UTF-8/GB18030/CESU-8 pattern literals. Existing EUC-TW
four-byte subject validation is outside this change. No subject cache or new global
roots are added.

Source `dcdfdc0329712220af4a3a5b410a48bd0240e500`; matched main `cc87d8b0`. Both freshly
built ordinary O2 binaries use compiler 9dec2ff6 and mgz 661a01d8. Clean Ruby 4.0.10
through `tools/ref_ruby.sh`, revision a704b7cd95a42cc0cf5f307137bf3aac0285b915, no
extras, Prism 1.8.2.

- Corpus --both:967/967 hash ON/OFF; VM:967 VM /0 fallback /0 differences. Expanded
corpus 949 matches both engines.
- Eight source gates, bracket check, default hygiene and explicit hygiene for the two
changed records pass.
- The selected Regexp cases pass (2 tests, 141 assertions) in all five executions. Whole
test_regexp is COMPLETE in all five, with identical before/after case vectors on each
engine; existing failures/errors remain.
- Rails titleize selections pass on both engines. Full StringExt/Inflector replay pairs
follow below.

| Whole Regexp mode | Tests/assertions/failures/errors |
| --- | --- |
| reference | 176 / 62651 / 1 / 1 |
| before-evaluator | 176 / 62595 / 4 / 3 |
| after-evaluator | 176 / 62595 / 4 / 3 |
| before-vm | 176 / 62595 / 4 / 3 |
| after-vm | 176 / 62595 / 4 / 3 |

Instructions retired, medians of three alternating pairs, 800 iterations. ASCII/Unicode-
neutral keep the same callback counts and outputs. The separate Unicode-regression
workload changes callback work while correcting the result.

| Case | Engine | Main | Candidate | Delta |
| --- | --- | --- | --- | --- |
| ascii | evaluator | 1,070,572,658 | 1,071,646,004 | +0.10% |
| ascii | VM | 1,072,274,895 | 1,074,655,921 | +0.22% |
| unicode_neutral | evaluator | 1,049,704,310 | 1,043,120,113 | -0.63% |
| unicode_neutral | VM | 1,045,526,950 | 1,047,446,654 | +0.18% |
| unicode_regression | evaluator | 1,100,465,945 | 1,084,174,393 | -1.48% |
| unicode_regression | VM | 1,103,975,659 | 1,079,369,915 | -2.23% |

Three alternating seed 12345 full Rails replay pairs, all files COMPLETE without bounds
events;600 s / 2 GiB family limits, jobs 2,MT_CPU=0. Owned native 89 install explicitly
reused from 1a454a94; installing/measured digests are separate. Peak family RSS in KiB:

| File | Main | Candidate |
| --- | --- | --- |
| string_ext_test.rb | 373536 / 344608 / 346896 | 342336 / 350176 / 342048 |
| inflector_test.rb | 349008 / 356080 / 366144 | 361584 / 351824 / 353584 |

RSS medians and ranges in KiB (three runs, same fixed seed):

| File | Main median (range) | Candidate median (range) | Median delta |
| --- | --- | --- | --- |
| string_ext_test.rb | 346,896 (344,608–373,536) | 342,336 (342,048–350,176) | -1.31% |
| inflector_test.rb | 356,080 (349,008–366,144) | 353,584 (351,824–361,584) | -0.70% |

Per-file Rails MATCH/RED from the first complete full-file RSS pair:

| File | Before | After |
| --- | --- | --- |
| activesupport/test/core_ext/string_ext_test.rb | 150 / 1 | 151 / 0 |
| activesupport/test/inflector_test.rb | 472 / 1 | 473 / 0 |

Both engines also run the targeted titleize selections, with the recorded before
failures and after passes. The full-file RSS pairs above measure the evaluator.

Legacy/other-encoding growth observations, actual time-l peak RSS, UTC times and binary
digests are retained in `railstest/framework/records/activesupport-lookbehind-character-
widths.json`. Rejected earlier candidate data is explicitly historical. No memory
improvement is claimed from noisy samples.

Review correction: multi-codepoint Unicode lists were one flat byte-node run and
received a byte count. The fixed min/max sum paths decode each contiguous literal run as
characters, with bounded six-byte lookahead. Corpus 949 includes the three reported
forms plus ASCII-first, three-codepoint, astral, anchor, character-class and exact-once
byte-repetition controls. The rejected R5 snapshot reproduces the difference; the
matched main control and corrected source match Ruby on both engines.
