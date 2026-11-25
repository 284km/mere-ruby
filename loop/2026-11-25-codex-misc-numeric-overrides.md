# Rational comparison overrides and Integer.sqrt arity

The branch starts from main `2e402b9422018f27ba5cc96a9a6ae797bcd22e8a`.
Both witnesses were reproduced with a clean Ruby 4.0.10, revision
`a704b7cd95`, before changing the interpreter. Builds use Mere
`9dec2ff687a08433247dbdb7729bc19c8522e538`, mgz
`661a01d8bb68f5acd68e3192bd47f081d179c436`, and ordinary O2.
No reference gems are installed.

## Comparison behavior

Numeric comparison shortcuts must step aside when the numeric receiver's
`<=>` has a Ruby definition. Sorting uses the same world-aware comparison
when a numeric comparator changes. Ordinary unchanged numeric sorting keeps
its existing path.

Ruby 4.0.10's two min/max paths have different receiver order. In
`vm_insnhelper.c`, `opt_newarray_send` asks the later element to compare with
the best so far. In `array.c`, `ary_min_generic` and `ary_max_generic` ask the
best to compare with the later element. `Array#minmax` calls those two Array
methods. A comparator that always returns 1 exposes this difference:

| Expression after redefining Rational#<=> to return 1 | Ruby 4.0.10 |
| --- | --- |
| `[Rational(1, 2), Rational(1, 3)].max` | `(1/3)` |
| `a = [Rational(1, 2), Rational(1, 3)]; a.max` | `(1/2)` |
| `[Rational(1, 2), Rational(1, 3)].min` | `(1/2)` |
| `a.min` | `(1/3)` |
| `a.minmax` | `[(1/3), (1/2)]` |
| `a.sort` | `[(1/3), (1/2)]` |

The evaluator preserves the literal call's syntax; the VM uses its real
`opt_newarray_send` instruction. Both check for an Array method replacement
after evaluating the elements, since an element can itself replace the
method. Aliases, undefined methods and active refinements keep normal method
dispatch. Corpus 1100 records callback order, answers 1/-1/0/nil, errors,
minmax, sort/sort!, comparator restoration and Array method replacement,
including replacement during element evaluation.

## Integer.sqrt

The instance-method arity table deliberately skips class receivers.
Integer.sqrt's own class-method implementation therefore checks its exact
one-argument contract before inspecting arguments. Corpus 1101 covers a call
inside another class method, send, Method#call, zero and excessive arguments,
and valid small and large values, with an ignored block.

## Related upstream checks and memory

Use the unchanged Ruby 4.0.10 source tree, `unittest/try.sh`, fixed `--seed=1`,
and `MERE_RUBY_GC_TIGHT=1`. Each file runs separately. Main and the final
candidate both pass the following on evaluator and VM:

| File | Selected tests | Tests | Assertions |
| --- | --- | ---: | ---: |
| `ruby/test_array.rb` | min/max/minmax, sort/sort!, sort_0, incomparable cases, replace/freeze during sorting (including the subclass) | 22 | 344 |
| `ruby/test_integer.rb` | square_root | 1 | 168 |
| `ruby/test_rational.rb` | cmp | 1 | 26 |
| `ruby/test_optimization.rb` | array_min, array_max | 2 | 24 |

Max RSS below is `/usr/bin/time -l`'s bytes for the fixed-seed, tight-GC
invocations, using unchanged binaries in the same directory beside their
C API headers. These are measurements of these selections, not full-suite
resource claims.

| File | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: |
| test_array | 180764672 | 179716096 | 222953472 | 220692480 |
| test_integer | 166674432 | 165806080 | 169246720 | 169754624 |
| test_rational | 167641088 | 164741120 | 173604864 | 169394176 |
| test_optimization | 171327488 | 173129728 | 171819008 | 168689664 |

An exploratory full-file test_array run on main was stopped in the unrelated
permutation-array-modified stress case. It supplies no complete-file result.
No full unit suite or Rails component suite is run. No test, exclusion or
budget is changed.

The PR description records the final full `run_corpus.sh --both` and VM
corpus results, source gates and record hygiene. Binaries kept outside the
source directory initially lacked the adjacent C API headers required by
corpus 1018; final corpus binaries live beside those headers. This is a test
layout requirement, not an interpreter change.

## Saved native comparator regression

The first full development sweep exposed recursion at corpus 930: a saved
native Float#<=> alias called the generic comparator, which had been changed
to redispatch the Ruby override. Keep the native comparator as a leaf and
ask the override only at the Array sorting and element-comparison sites.
Corpus 930, 1100 and 1101 now match Ruby on both engines. The RSS table above
was remeasured for this corrected O2 binary.

Pre-review acceptance on the R3 O2 binary: `run_corpus.sh --both` passes
883/883 corpus programs with the hash index ON and OFF. The subsequent
`MERE_RUBY_VM=1 run_corpus.sh --both` also passes 883/883 with the index ON
and OFF. Both invocations run all source gates and full record_hygiene.
The bracket-depth check passes (155 required, 1024 supplied). No corpus
exclusion, assertion, resource budget or workflow was changed.

## Review correction: numeric hot-path cost

The requested 2,000-element / 200-iteration min/max/sort probe prints
983200.0 on clean Ruby 4.0.10, main 323706a7, and both candidate modes.
The pre-review R3 candidate costs 34,563,634,177 instructions on the
evaluator versus 33,647,753,858 on main, and 34,451,062,068 versus
33,554,890,230 on the VM (about 2.7% more).

R4 caches the absence of numeric comparator overrides behind mro_now's
method-table generation. opt_cmp uses that cached answer before the
class-specific lookup. Comparator replacement still invalidates the cache;
corpus 1100 now primes the plain cache before redefining Rational#<=>.
The cache retains two integer counters and no Ruby values.

The same probe after caching, with `MERE_RUBY_GC_TIGHT=1 --seed=1`:

| Engine | Main instructions | Candidate instructions | Main max RSS bytes | Candidate max RSS bytes |
| --- | ---: | ---: | ---: | ---: |
| Evaluator | 33,777,153,198 | 33,800,438,393 | 110575616 | 110837760 |
| VM | 33,635,367,980 | 33,675,326,648 | 112377856 | 111869952 |

The measured difference is 0.07% / 0.12%. The main baseline here is the
unchanged 323706a7 O2 build with the same compiler and mgz pins.

Selected unchanged upstream files were repeated on R4, one file at a time,
with tight GC and seed 1. All main and candidate runs pass:

| File | Result | Main evaluator RSS | Candidate evaluator RSS | Main VM RSS | Candidate VM RSS |
| --- | --- | ---: | ---: | ---: | ---: |
| ruby/test_array.rb | 22 tests, 344 assertions, 0 failures, 0 errors, 0 skips | 180961280 | 181551104 | 219987968 | 222527488 |
| ruby/test_integer.rb | 1 tests, 168 assertions, 0 failures, 0 errors, 0 skips | 166412288 | 165822464 | 167264256 | 169017344 |
| ruby/test_rational.rb | 1 tests, 26 assertions, 0 failures, 0 errors, 0 skips | 166445056 | 165838848 | 170000384 | 169836544 |
| ruby/test_optimization.rb | 2 tests, 24 assertions, 0 failures, 0 errors, 0 skips | 168378368 | 171507712 | 171622400 | 170819584 |

The R4 full evaluator and subsequent VM corpus sweeps each pass 883/883
programs with hash indexing ON and OFF, including all source gates and
full record_hygiene. The R3 acceptance above remains historical evidence;
these are separate completed sweeps of the corrected R4 O2 binary.

## Review correction: static arrays and splats

The evaluator's literal min/max branch also caught static literals and
arrays with splats. CRuby compiles a static array with duparray and makes
an ordinary Array call; a splat also uses ordinary dispatch. With
Rational#<=> returning 1, both [0.5r, 0.25r].max and [0.5r, *tail].max
must keep 1/2. The prior candidate evaluator returned 1/4; its VM was
already correct.

The special evaluator branch now requires no splat and at least one
nonstatic element. The static-expression check preserves the parser's
literal and frozen-string markers; it does not treat nested containers
as static literals. Corpus 1100 adds Rational static/splat min/max with
callback order and 1/-1/0/nil results, plus Float static/splat controls
and a dynamic Float literal control. Corpus 1100, 1101 and 930 match
clean Ruby on both engines. A separate String/frozen-String, Regexp,
Symbol and Complex shape probe matches too.

The final R5 O2 binary repeats the unchanged upstream selections with
--seed=1 and MERE_RUBY_GC_TIGHT=1. Reference, main and candidate pass:

| File | Tests / assertions | Main evaluator RSS | Candidate evaluator RSS | Main VM RSS | Candidate VM RSS |
| --- | --- | ---: | ---: | ---: | ---: |
| ruby/test_array.rb | 22 / 344 | 178765824 | 179912704 | 223510528 | 220364800 |
| ruby/test_integer.rb | 1 / 168 | 164790272 | 163512320 | 167165952 | 167837696 |
| ruby/test_rational.rb | 1 / 26 | 165347328 | 163954688 | 169476096 | 172539904 |
| ruby/test_optimization.rb | 2 / 24 | 170016768 | 170672128 | 171753472 | 170196992 |

RSS is /usr/bin/time -l bytes. The requested hot-path probe was also
repeated as three alternating main/candidate runs per engine, with tight
GC and --seed=1. Every result is 983200.0. Median instructions and the
maximum RSS across the three runs:

| Engine | Main instructions | R5 instructions | Change | Main max RSS | R5 max RSS |
| --- | ---: | ---: | ---: | ---: | ---: |
| Evaluator | 33667977953 | 33730502090 | +0.19% | 110559232 | 110723072 |
| VM | 33636517143 | 33685184567 | +0.14% | 112345088 | 111820800 |

The main baseline for this performance comparison is unchanged 323706a7,
using the same compiler and mgz pins. The new classifier adds no global
object retention or cache.

The review also records existing follow-ups outside this correction:
Integer/Rational coerce comparison dispatch, max(n), each.max, max_by,
sort_by, Array#<=>, and Rational#coerce/#== overrides. They are not
represented as fixed by this PR.


Final R5 acceptance is complete: sh run_corpus.sh --both and
MERE_RUBY_VM=1 sh run_corpus.sh --both each pass 883/883 programs with
hash indexing ON and OFF. Both fresh sweeps pass all source gates and
full record_hygiene. The bracket-depth gate passes (155 / 1024), and
this updated loop note passes explicit record_hygiene. The related-test
main comparison above is also repeated on the same known 323706a7 O2
baseline used for performance. Code, regression cases and the completed
R4/R5 record are committed together. No workflow is changed.
