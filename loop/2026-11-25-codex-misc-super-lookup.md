# Extended primitive receivers and beginless Range super

B3 and B4. Branch base: main `ab5a9bfd`. Reference: clean Ruby 4.0.10, revision
`a704b7cd95`. Build: Mere `9dec2ff6`, mgz `661a01d8`, O2. No reference
gems were installed.

Corpus 1102 and 1103 cover String/Array/Hash extension chains, bound super methods, arguments and blocks, and beginless Range count/min/max through prepend. Both programs match Ruby on evaluator and VM. Lookup starts at the receiver singleton class; the Range native entry remains an explicit super target.

## Related upstream comparisons

Unchanged Ruby 4.0.10 files run one at a time through unittest/try.sh.
Every invocation uses `--seed=1` and `MERE_RUBY_GC_TIGHT=1`. Reference,
main and candidate pass the selections below on both engines. RSS is the
maximum resident set size in bytes from `/usr/bin/time -l`.

| Selection | Result | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | --- | ---: | ---: | ---: | ---: |
| ruby/test_module.rb | 29 tests, 86 assertions, 0 failures, 0 errors, 0 skips | 177242112 | 176603136 | 204832768 | 202981376 |
| ruby/test_method.rb | 15 tests, 72 assertions, 0 failures, 0 errors, 0 skips | 169000960 | 166576128 | 186695680 | 185892864 |
| ruby/test_range.rb | 4 tests, 71 assertions, 0 failures, 0 errors, 0 skips | 172015616 | 169951232 | 185827328 | 182976512 |

## Acceptance still running

The full `run_corpus.sh --both` and `MERE_RUBY_VM=1 run_corpus.sh --both`
sweeps are queued sequentially. Their source gates and full record_hygiene
results will be recorded after completion. The direct witnesses and upstream
selections above do not constitute a full-corpus result. No full unit suite
or Rails component suite was run, and no workflow is changed.
