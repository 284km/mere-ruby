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

A fresh full `run_corpus.sh --both` is running, followed sequentially by
`MERE_RUBY_VM=1 run_corpus.sh --both`. Neither full result is claimed here
until the run completes.
