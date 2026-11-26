# Lookbehind character widths

Unicode lookbehind selected incorrect widths, so ActiveSupport titleize produced
`Fred’S` instead of `Fred’s`. Measure widths and candidate positions in whole
characters, including six-byte CESU-8 literals. Positive plain alternatives preserve
pattern order/capture backtracking; calls and backreferences retain their shared trial
range. Known legacy decoders step back from character boundaries without rescanning the
whole prefix at every match.

Corpus 949 covers titleize, alternatives/captures/subroutines, legacy subject
boundaries, and positive/negative UTF-8/GB18030/CESU-8 pattern literals. Existing EUC-TW
four-byte subject validation is outside this change. No subject cache or new global
roots are added.

Source `097c9f52317736124231cb053baac3b4c425793f`; matched main `cc87d8b0`. Both fresh
ordinary O2 builds use compiler 9dec2ff6 and mgz 661a01d8. Clean Ruby 4.0.10 through
`tools/ref_ruby.sh`, revision a704b7cd95a42cc0cf5f307137bf3aac0285b915, no extras, Prism
1.8.2.

- Corpus --both: 967/967 hash ON/OFF; VM: 967 VM / 0 fallback / 0 differences. Expanded
corpus 949 matches both engines.
- Eight source gates, bracket check and default hygiene pass; explicit changed-record
hygiene checked separately.
- The selected Regexp tests pass in all five executions: 2 tests / 141 assertions. Whole
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
| ascii | evaluator | 1,073,576,466 | 1,075,291,210 | +0.16% |
| ascii | VM | 1,073,953,180 | 1,075,880,907 | +0.18% |
| unicode_neutral | evaluator | 1,046,799,346 | 1,050,692,058 | +0.37% |
| unicode_neutral | VM | 1,047,930,807 | 1,049,727,793 | +0.17% |
| unicode_regression | evaluator | 1,102,568,407 | 1,081,484,612 | -1.91% |
| unicode_regression | VM | 1,104,594,457 | 1,080,770,982 | -2.16% |

Three alternating seed 12345 full Rails replay pairs, all files COMPLETE without bounds
events; 600 s / 2 GiB family limits, jobs 2, MT_CPU=0. Owned native 89 install
explicitly reused from 1a454a94; installing/measured digests are separate. Peak family
RSS in KiB:

| File | Main | Candidate |
| --- | --- | --- |
| string_ext_test.rb | 352240 / 337984 / 340336 | 367184 / 362144 / 366464 |
| inflector_test.rb | 352288 / 359248 / 354416 | 350400 / 363904 / 350816 |

Full evaluator replays: 622 MATCH / 2 RED before, 624 MATCH / 0 RED after;
MISSING/BOTH/UNCF/EXTRA are zero. Case order differs on both builds; identity-based
comparisons and order differences are retained in the record.

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

StringExt median peak RSS is +7.7% in these samples (340,336 -> 366,464 KiB). Correcting
the titleize failures changes assertion and callback work; these observations do not
isolate retained memory. All samples are shown above.
