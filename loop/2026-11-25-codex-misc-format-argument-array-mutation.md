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

## Acceptance still running

Full `run_corpus.sh --both` and `MERE_RUBY_VM=1 run_corpus.sh --both`
sweeps, their source gates, bracket-depth checks and record_hygiene are
queued. Results will be recorded after completion. The checks above are
not a full-corpus claim. No full unit suite or Rails component suite was
run and no workflow is changed.

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
`run_corpus.sh --both` and `MERE_RUBY_VM=1 run_corpus.sh --both` are running;
source gates and full record_hygiene are part of those commands.
