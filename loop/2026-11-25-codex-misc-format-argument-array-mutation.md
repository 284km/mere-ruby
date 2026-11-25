# Detect array length changes during String formatting

B12. Branch base: main `fdda9150`. Reference: clean Ruby 4.0.10,
revision `a704b7cd95`; Mere `9dec2ff6`, mgz `661a01d8`, O2. No reference
gems were installed.

Corpus 1111 matches Ruby on both engines. String#% retains the original
argument array and checks its length before reading an argument and after
formatting. Same-length element replacements remain visible. Width/precision
coercion, numbered arguments, mutation by the final conversion, to_ary, nested
formatting and unrelated source-array mutation after a sprintf splat are
covered. No global formatter source state is added.

## Related upstream comparisons

Each unchanged Ruby 4.0.10 file runs separately through unittest/try.sh,
with `--seed=1` and `MERE_RUBY_GC_TIGHT=1`. Max RSS below is in bytes from
`/usr/bin/time -l`, with binaries beside their C API headers.

| File | Main result | Candidate result | Main evaluator RSS | Candidate evaluator RSS | Main VM RSS | Candidate VM RSS |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| ruby/test_sprintf.rb | 7 tests, 59 assertions, 1 failures, 0 errors, 0 skips | 7 tests, 60 assertions, 0 failures, 0 errors, 0 skips | 163889152 | 164921344 | 162840576 | 164888576 |

## Initial acceptance history

The initial focused selections passed but review exposed the stale-encoding
regression described below. The final corrected O2 source was rebuilt and
its focused and complete acceptance runs were repeated.

## Review correction: live values and result encoding

The initial live argument reads still negotiated the final encoding from
the original list. Equal-length replacement could therefore produce bytes
from the new value labelled with the old value's encoding.

Encoding is now negotiated when each directive actually converts its
argument, including to_s/inspect callback results. Each formatting call
owns its encoding state; nested formatting cannot overwrite it. Earlier
consumed arguments retain their contribution even when a later callback
replaces their source slots. The obsolete post-format scan is removed.

Corpus 1111 adds replacement between UTF-8, EUC-JP and ASCII-8BIT,
replacement of an already consumed argument, callback results, and nested
formatting. The complete witness matches clean Ruby 4.0.10 on both engines
with tight GC. The seven unchanged test_sprintf.rb selections were repeated
with --seed=1 and MERE_RUBY_GC_TIGHT=1, one file at a time:

| Engine | Main result | Candidate result | Main max RSS bytes | Candidate max RSS bytes |
| --- | --- | --- | ---: | ---: |
| Evaluator | 7 tests / 59 assertions / 1 failure | 7 / 60 / 0 failures | 166051840 | 163004416 |
| VM | 7 tests / 59 assertions / 1 failure | 7 / 60 / 0 failures | 165609472 | 163708928 |

The clean reference passes 7 tests / 60 assertions. The corrected O2 full
`run_corpus.sh --both` and `MERE_RUBY_VM=1 run_corpus.sh --both` each pass
884/884 programs with the hash index ON and OFF. Both commands pass all
source gates and full record_hygiene.

## R4 acceptance history

The final source correction is 3608af46. Both complete 884/884 sweeps
include all new encoding/mutation regressions; no program is excluded.
The generated C passes the bracket-depth gate, and this record is checked
explicitly with record_hygiene. The English inline review reply records
the correction and the new regression cases. No full unit suite or Rails
component suite was run, and no workflow is changed.

## Review correction: inspect only once

The new review found that a non-String inspect result made %p call
inspect again on the original object. The exact witness returns ["123", 1]
on clean Ruby and current main, but the R4 candidate raises on the second
inspect call, on both engines.

The formatter now calls inspect once and converts its returned value with
the existing interpolation conversion helper. That result still passes
through the per-invocation encoding negotiation added in R4. Corpus 1111
adds Integer, nil, boolean, Symbol and Array inspect results, objects whose
to_s returns UTF-8 or binary text, and a non-String to_s fallback. Counters
check inspect/to_s calls; to_str must not be used. All 28 output lines of
1111, plus corpus 982, match clean Ruby on both engines with tight GC.

The final R5 O2 binary repeats unchanged test_sprintf.rb selections with
--seed=1 and MERE_RUBY_GC_TIGHT=1. Eight tests pass 61 assertions on the
reference and both candidate engines, versus 60 assertions and one failure
on both main engines. The selection includes the original inspect test.

| Engine | Main max RSS bytes | Candidate max RSS bytes |
| --- | ---: | ---: |
| Evaluator | 166526976 | 165003264 |
| VM | 164790272 | 163381248 |

Separate complete R5 sh run_corpus.sh --both and
MERE_RUBY_VM=1 sh run_corpus.sh --both sweeps each pass 884/884 programs
with indexing ON and OFF, including all source gates and full
record_hygiene. The generated-C bracket gate and an explicit hygiene
check of this updated note pass. Code, regressions and this record are
committed and pushed together after local validation.
