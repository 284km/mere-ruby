# Definition-site yield in define_method bodies

B6. Branch base: main `50644298`. Reference: clean Ruby 4.0.10,
revision `a704b7cd95`; Mere `9dec2ff6`, mgz `661a01d8`, O2. No reference
gems were installed.

Corpus 1105 matches Ruby on both engines, covering caller blocks and &block
parameters, lexical yield through nested iterators, optional defaults,
aliases, Proc arguments and singleton methods, defined?(yield), active and
orphan break, and lambda break. All registration paths, including the
class-body statement path, record the definition-site yield block and its real
home/lambda metadata. Parameter binding continues to receive the caller block.

## Related upstream comparisons

Each unchanged Ruby 4.0.10 file runs separately through unittest/try.sh,
with `--seed=1` and `MERE_RUBY_GC_TIGHT=1`. Max RSS below is in bytes from
`/usr/bin/time -l`, with binaries beside their C API headers.

| File | Main result | Candidate result | Main evaluator RSS | Candidate evaluator RSS | Main VM RSS | Candidate VM RSS |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| ruby/test_method.rb | 15 tests, 45 assertions, 0 failures, 0 errors, 0 skips | 15 tests, 45 assertions, 0 failures, 0 errors, 0 skips | 166838272 | 168083456 | 186351616 | 186482688 |
| ruby/test_defined.rb | 1 tests, 2 assertions, 0 failures, 0 errors, 0 skips | 1 tests, 2 assertions, 0 failures, 0 errors, 0 skips | 164347904 | 163545088 | 165117952 | 163889152 |
| ruby/test_proc.rb | 4 tests, 11 assertions, 0 failures, 0 errors, 0 skips | 4 tests, 11 assertions, 0 failures, 0 errors, 0 skips | 173096960 | 173129728 | 206520320 | 204914688 |

## Acceptance still running

Full `run_corpus.sh --both` and `MERE_RUBY_VM=1 run_corpus.sh --both`
sweeps, their source gates, bracket-depth checks and record_hygiene are
queued. Results will be recorded after completion. The checks above are
not a full-corpus claim. No full unit suite or Rails component suite was
run and no workflow is changed.
