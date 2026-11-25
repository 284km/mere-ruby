# Private constant qualifiers in defined?

B5. Branch base: main `ab5a9bfd`. Reference: clean Ruby 4.0.10, revision
`a704b7cd95`. Build: Mere `9dec2ff6`, mgz `661a01d8`, O2. No reference
gems were installed.

Corpus 1104 covers private qualifier chains, absolute paths, aliases, legal
lexical access to a bare private constant, inheritance and const_missing side
effects. Both engines match Ruby. The evaluator checks each real qualifier
without invoking const_missing; the VM uses the namespace value it already
resolved.

## Initial upstream comparisons (before the autoload correction)

Unchanged Ruby 4.0.10 files run one at a time through unittest/try.sh.
Every invocation uses `--seed=1` and `MERE_RUBY_GC_TIGHT=1`. Reference,
main and candidate pass the selections below on both engines. RSS is the
maximum resident set size in bytes from `/usr/bin/time -l`.

| Selection | Result | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | --- | ---: | ---: | ---: | ---: |
| ruby/test_defined.rb | 2 tests, 4 assertions, 0 failures, 0 errors, 0 skips | 163102720 | 164331520 | 163168256 | 164282368 |
| ruby/test_module.rb | 10 tests, 54 assertions, 0 failures, 0 errors, 0 skips | 176881664 | 176668672 | 204767232 | 206028800 |

## Initial acceptance history

The first full sweep failed on existing corpus 361, as detailed below.
The initial focused selections did not reveal that regression. The failed
sweep is preserved as development evidence and is not counted as a pass.

## Full-corpus autoload regression and correction

The first complete evaluator sweep exposed a regression in existing
corpus 361: defined?(Object::AutoA361), a pending top-level autoload,
answered nil. The new scoped-read path looked only for Object-qualified
registry keys, while Object's top-level autoloads use bare names.

The Object receiver now delegates its final defined? query to the existing
absolute top-level lookup, preserving privacy and pending-autoload behavior
without loading the final constant. Corpus 1104 additionally checks both
Object-qualified and absolute pending constants, no eager load, and loading
an intermediate qualifier when required. Existing 361 and 736 plus 1104
match the clean reference on both engines with tight GC.

The corrected O2 evaluator sweep passes 884/884 programs with the hash
index ON and OFF, including all source gates and full record_hygiene.
The subsequent VM sweep also passes 884/884 with both index settings.
The failed historical sweep is not counted as a pass. Selected unchanged
upstream cases were repeated with seed 1 and tight GC, all passing:

| File | Tests/assertions | Main evaluator RSS | Candidate evaluator RSS | Main VM RSS | Candidate VM RSS |
| --- | --- | ---: | ---: | ---: | ---: |
| ruby/test_defined.rb | 2 / 4 | 162332672 | 165036032 | 162463744 | 166248448 |
| ruby/test_module.rb | 10 / 54 | 175570944 | 175685632 | 203112448 | 204242944 |

## Completed acceptance on the corrected O2 source

`sh run_corpus.sh --both` and the subsequent
`MERE_RUBY_VM=1 sh run_corpus.sh --both` each pass 884/884 programs,
with the hash index ON and OFF. Both pass all source gates and full
record_hygiene. `MR_C=mr.c sh tools/bracket_depth_check.sh` passes on the
final emitted C; the loop record is also checked explicitly.

The mere-pr-review-watch Object-autoload finding is fixed in 9081c5f8,
with an English inline reply and regression cases. No full unit suite or
Rails component suite was run, and no workflow is changed.
