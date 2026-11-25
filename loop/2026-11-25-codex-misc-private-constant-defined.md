# Private constant qualifiers in defined?

B5. Branch base: main `ab5a9bfd`. Reference: clean Ruby 4.0.10, revision
`a704b7cd95`. Build: Mere `9dec2ff6`, mgz `661a01d8`, O2. No reference
gems were installed.

Corpus 1104 covers private qualifier chains, absolute paths, aliases, legal lexical access to a bare private constant, inheritance and const_missing side effects. Both engines match Ruby. The evaluator checks each real qualifier without invoking const_missing; the VM uses the namespace value it already resolved.

## Related upstream comparisons

Unchanged Ruby 4.0.10 files run one at a time through unittest/try.sh.
Every invocation uses `--seed=1` and `MERE_RUBY_GC_TIGHT=1`. Reference,
main and candidate pass the selections below on both engines. RSS is the
maximum resident set size in bytes from `/usr/bin/time -l`.

| Selection | Result | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | --- | ---: | ---: | ---: | ---: |
| ruby/test_defined.rb | 2 tests, 4 assertions, 0 failures, 0 errors, 0 skips | 163102720 | 164331520 | 163168256 | 164282368 |
| ruby/test_module.rb | 10 tests, 54 assertions, 0 failures, 0 errors, 0 skips | 176881664 | 176668672 | 204767232 | 206028800 |

## Acceptance still running

The full `run_corpus.sh --both` and `MERE_RUBY_VM=1 run_corpus.sh --both`
sweeps are queued sequentially. Their source gates and full record_hygiene
results will be recorded after completion. The direct witnesses and upstream
selections above do not constitute a full-corpus result. No full unit suite
or Rails component suite was run, and no workflow is changed.
