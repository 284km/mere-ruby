# Replaced Module attribute helpers and super

B8. Branch base: main `50644298`. Reference: clean Ruby 4.0.10, revision
`a704b7cd95`. Build: Mere `9dec2ff6`, mgz `661a01d8`, O2. No reference
gems were installed.

Corpus 1107 verifies native attribute helpers through a prepended wrapper,
then replacement of Module attr/attr_reader/attr_writer/attr_accessor and
NoMethodError from super. A native alias retained before prepend still works.
Both engines match Ruby.

## Related upstream comparisons

Unchanged Ruby 4.0.10 files run one at a time through unittest/try.sh.
Every invocation uses `--seed=1` and `MERE_RUBY_GC_TIGHT=1`. Reference,
main and candidate pass the selections below on both engines. RSS is the
maximum resident set size in bytes from `/usr/bin/time -l`.

| Selection | Result | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | --- | ---: | ---: | ---: | ---: |
| ruby/test_module.rb | 5 tests, 34 assertions, 0 failures, 0 errors, 0 skips | 176996352 | 176177152 | 204750848 | 204914688 |
| ruby/test_method.rb | 15 tests, 72 assertions, 0 failures, 0 errors, 0 skips | 169525248 | 167772160 | 186007552 | 184647680 |

## Acceptance still running

The full `run_corpus.sh --both` and `MERE_RUBY_VM=1 run_corpus.sh --both`
sweeps are queued sequentially. Their source gates and full record_hygiene
results will be recorded after completion. The direct witnesses and upstream
selections above do not constitute a full-corpus result. No full unit suite
or Rails component suite was run, and no workflow is changed.
