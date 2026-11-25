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


## Review correction: literal copying and directive cost

The human review identified a printf regression and a per-character cost.
With no prior formatter invocation, printf of non-ASCII text raised an
encoding error whose second encoding name was empty. Earlier rescued
formatting errors could leave the global format context set and mask it.
The new corpus starts a fresh child with Kernel printf, stdout/STDOUT,
stderr, explicit-IO printf and IO#printf; captured stderr is also compared
as corpus output. It additionally covers binary conversion results followed
by UTF-8 literal text (positional, named and callback forms), and a UTF-8
prefix which must still reject an incompatible argument.

Literal bytes are now copied without encoding negotiation, matching Ruby.
The prefix is stored only before an actual directive, so argument
conversions still negotiate against the correct output-so-far. Retaining
the accumulating String in the vector on every byte is removed. R6 corpus
1111 and 982 plus the exact review probes match the reference on both
engines with tight GC.

The final R6 O2 binary is a1e0168b907158da887d3f6ebabbcf3d89caceda912dc95f3d815969de7dbeb2.
Unchanged upstream files were compared with main a63e47c3 separately,
using --seed=1 and MERE_RUBY_GC_TIGHT=1. test_sprintf selections exclude
only the review's known long-running test_width_underflow; its resource
behavior is not claimed fixed or passing. test_m17n is the whole file.

| File | Reference | Main evaluator / VM | Candidate evaluator / VM |
| --- | --- | --- | --- |
| test_sprintf | 34 tests, 37679 assertions, 0 failures | 34 tests, 37674 assertions, 2 failures / same | 34 tests, 37679 assertions, 0 failures / same |
| test_m17n | 127 tests, 3800 assertions, 0 failures, 1 skip | 127 tests, 3794 / 3796 assertions, 0 failures, 1 skip | same as main |

The differing m17n assertion totals are preserved; the candidate does not
claim to match the reference count. The initial eight sprintf selections
also pass 61 assertions on the reference and both candidate engines,
versus 60 assertions and one failure on both main engines.

Max RSS in bytes for these expanded upstream runs:

| File | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: |
| test_sprintf | 200916992 | 218464256 | 201261056 | 218234880 |
| test_m17n | 233062400 | 228868096 | 228294656 | 223723520 |

bench/string_format_literals.rb repeats the six review shapes with
deterministic inputs and --seed=1, tight GC, three alternating runs of
unchanged main a63e47c3, R5 and R6 per engine. Every checksum matches clean
Ruby. The checksum/bytesize bookkeeping is included in every binary's
counts; these are not presented as the review's exact instruction totals.
Median instructions:

| Case | Main evaluator | R5 evaluator | R6 evaluator | Main VM | R5 VM | R6 VM |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| mixed | 10660349144 | 10796275090 | 10696072748 | 11306212583 | 11458592190 | 11338433687 |
| single | 10170642914 | 10326711511 | 10273632687 | 12306939464 | 12438750032 | 12390887557 |
| message | 5702815462 | 6865013073 | 5675567237 | 6534188247 | 7686542173 | 6508833364 |
| japanese | 5587175369 | 11131450689 | 5578614177 | 6417017051 | 11895094957 | 6398182233 |
| long_ascii | 2927239870 | 6192097235 | 2782766151 | 2961176414 | 6211815191 | 2809693631 |
| long_utf8 | 8091085545 | 38061444719 | 7660074694 | 8143933059 | 38126944787 | 7746422571 |

Maximum RSS in bytes across each set of three runs:

| Case | Main evaluator | R5 evaluator | R6 evaluator | Main VM | R5 VM | R6 VM |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| mixed | 120438784 | 172589056 | 159006720 | 116785152 | 168951808 | 155369472 |
| single | 104267776 | 155271168 | 150536192 | 105857024 | 156958720 | 152272896 |
| message | 94650368 | 368050176 | 121831424 | 95125504 | 368951296 | 122159104 |
| japanese | 93028352 | 404619264 | 119537664 | 94126080 | 404733952 | 124387328 |
| long_ascii | 80347136 | 2053472256 | 82640896 | 81297408 | 2536570880 | 83492864 |
| long_utf8 | 89473024 | 6610501632 | 98385920 | 91586560 | 7758430208 | 100466688 |

The length-dependent instruction and allocation cost is removed. Short
formats remain about 0.3-1% above this main baseline, the message and
Japanese forms are approximately unchanged, and long forms use about 5%
fewer instructions. The final R6 sh run_corpus.sh --both and
MERE_RUBY_VM=1 sh run_corpus.sh --both sweeps each pass 884/884 programs
with hash indexing ON and OFF, including all source gates and full
record_hygiene. They run serially to avoid shared-file races. The generated
C bracket gate (155 / 1024) and explicit hygiene of this note pass.
Code, regressions, benchmark and this completed record are pushed together.
No full unit suite or Rails component suite was run; no workflow is changed.
