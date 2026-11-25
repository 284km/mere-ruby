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


## Review correction: release scratch arenas and preserve printf encoding

The R6 review found two additional blockers. A fresh per-call Vec retained
its allocations, including the captured prefix, after formatting returned.
The printf wrapper also started every format as UTF-8 and lost the actual
String encoding before negotiation.

Formatting now borrows a reusable scratch slot. Each slot has a private
arena, recycled on both normal and exceptional return; clearing its String
fields alone would retain arena copies. Busy slots are kept separate for
nested calls and interleaved Fibers; a first-free search permits returns
in a different order. The resulting encoding is copied out before recycling.
Named keys and the original format encoding are invocation-local as well.
The printf entry points pass the String value through, preserving its
encoding and strict to_str conversion before the common formatting path.

Corpus 1111 adds EUC-JP, Windows-31J and binary printf formats in fresh
children, Kernel/stdout/STDOUT/stderr/explicit IO and File entry points,
percent-s and percent-c, and an incompatible binary/UTF-8 control. Captured
stdout/stderr bytes and status are checked. Nested named callbacks,
rescued errors, throw, and non-LIFO interleaved Fibers guard slot ownership.
The final O2 corpus 1111, corpus 982 and the exact literal review probe
match clean Ruby 4.0.10 on evaluator and VM with tight GC.

The final R8 ordinary O2 binary SHA-256 is
59dc7e3d5c4169c1ec4233b2b062a3bc8fc0312a53d951417a07bff9ec8cb032.
Compiler and mgz remain pinned at 9dec2ff6 and 661a01d8. This section
supersedes R6 acceptance for the corrected head.

The unchanged expanded upstream selections were repeated with --seed=1
and MERE_RUBY_GC_TIGHT=1, one file at a time. test_sprintf still excludes
only test_width_underflow, the separately known main/candidate resource
hang; that case is not claimed passing. Reference passes 34 tests / 37679
assertions. Main a63e47c3 passes 34 / 37674 with two failures; candidate
passes 34 / 37679 with no failures, on both engines. Whole test_m17n has
127 tests, zero failures and one skip: reference 3800 assertions, main and
candidate 3794 evaluator / 3796 VM. The count difference is preserved.

| File | Main evaluator RSS | Candidate evaluator RSS | Main VM RSS | Candidate VM RSS |
| --- | ---: | ---: | ---: | ---: |
| test_sprintf | 197099520 | 199032832 | 200425472 | 209256448 |
| test_m17n | 229933056 | 230670336 | 228229120 | 226082816 |

### RSS against formatting call count

bench/string_format_retention.rb is measured with tight GC, --seed=1,
three alternating runs per binary, case, count and engine. Values are
maximum RSS bytes across those three runs; ordinary O2 binaries are main
d4e5ba50, reviewed R6 and final R8. All 216 executions finish successfully
and match the reference witness output. The main d4 control is separate
from the a63 control used for upstream files and instruction measurements.

| Case | Calls | Engine | Main RSS | R6 RSS | R8 RSS |
| --- | ---: | --- | ---: | ---: | ---: |
| plain | 100000 | eval | 95404032 | 109215744 | 91062272 |
| plain | 100000 | vm | 95715328 | 109543424 | 91226112 |
| plain | 400000 | eval | 108462080 | 167510016 | 91684864 |
| plain | 400000 | vm | 106201088 | 168148992 | 92143616 |
| plain | 800000 | eval | 121913344 | 244318208 | 91684864 |
| plain | 800000 | vm | 118833152 | 244989952 | 92340224 |
| nested | 10000 | eval | 77316096 | 78725120 | 74842112 |
| nested | 10000 | vm | 79151104 | 80478208 | 76759040 |
| nested | 40000 | eval | 96190464 | 107200512 | 91832320 |
| nested | 40000 | vm | 97583104 | 108691456 | 93323264 |
| nested | 80000 | eval | 105070592 | 128466944 | 97730560 |
| nested | 80000 | vm | 105988096 | 129712128 | 99237888 |
| rescued | 10000 | eval | 98729984 | 96010240 | 94617600 |
| rescued | 10000 | vm | 98926592 | 98516992 | 97075200 |
| rescued | 40000 | eval | 106397696 | 106446848 | 99876864 |
| rescued | 40000 | vm | 101974016 | 105840640 | 99991552 |
| rescued | 80000 | eval | 104071168 | 113524736 | 101351424 |
| rescued | 80000 | vm | 104316928 | 112738304 | 101449728 |
| long | 5000 | eval | 80674816 | 82608128 | 78675968 |
| long | 5000 | vm | 81510400 | 83460096 | 79544320 |
| long | 20000 | eval | 88145920 | 101466112 | 88064000 |
| long | 20000 | vm | 88670208 | 102088704 | 86228992 |
| long | 50000 | eval | 95862784 | 131399680 | 92307456 |
| long | 50000 | vm | 96436224 | 132448256 | 93077504 |

Plain formatting no longer has the R6 linear retained-memory slope: R8
stays near 91-92 MB from 100000 to 800000 calls, while R6 grows from
109 MB to 245 MB. Nested, rescued and long formats also stay below the
unchanged main control at the largest counts. Their total process RSS
still includes normal interpreter warm-up; it is not claimed flat.

### Six-shape instruction and RSS comparison

bench/string_format_literals.rb repeats the same six deterministic shapes
with --seed=1, tight GC and three alternating runs of main a63e47c3, R6
and R8. Every checksum matches clean Ruby. Counts include checksum/bytesize
bookkeeping; they are not the reviewer's exact instruction totals. These
are medians for instructions and maxima across three runs for RSS bytes.

| Case | Engine | Main instructions | R6 instructions | R8 instructions | R8 vs main | R8 RSS |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| mixed | eval | 10651529712 | 10670231235 | 10551755394 | -0.94% | 112541696 |
| mixed | vm | 11297070304 | 11320718115 | 11195305121 | -0.90% | 108953600 |
| single | eval | 10163373631 | 10254560361 | 10107667068 | -0.55% | 93437952 |
| single | vm | 12290571318 | 12393003760 | 12238400795 | -0.42% | 94437376 |
| message | eval | 5696023985 | 5666222856 | 5661570331 | -0.60% | 91193344 |
| message | vm | 6527891666 | 6498754624 | 6486711906 | -0.63% | 90767360 |
| japanese | eval | 5593060324 | 5574620321 | 5567234311 | -0.46% | 89620480 |
| japanese | vm | 6416368722 | 6402059795 | 6380817237 | -0.55% | 89882624 |
| long_ascii | eval | 2927742354 | 2778755294 | 2835559970 | -3.15% | 78741504 |
| long_ascii | vm | 2959465383 | 2803772117 | 2877529970 | -2.77% | 79675392 |
| long_utf8 | eval | 8084979840 | 7659334566 | 7852738543 | -2.87% | 87654400 |
| long_utf8 | vm | 8133713346 | 7736557963 | 7929362326 | -2.51% | 89620480 |

The final R8 generated-C bracket gate passes, 155 required / 1024 supplied.
sh run_corpus.sh --both: 884/884 pass, hash indexing ON and OFF.
MERE_RUBY_VM=1 sh run_corpus.sh --both: 884/884 pass, indexing ON/OFF.
Both fresh complete commands pass all source gates and full record_hygiene.
They run serially; no corpus program is excluded. The updated loop note
passes explicit record_hygiene before the single code/regression/record push.
No full unit suite or Rails component suite was run; no workflow changed.
