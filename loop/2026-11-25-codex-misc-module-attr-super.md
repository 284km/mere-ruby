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

## Completed local acceptance

The unchanged O2 binary for head 91936f3b completes both full sweeps:

- `sh run_corpus.sh --both`: 884/884 pass, hash indexing ON and OFF.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: 884/884 pass, indexing ON/OFF.
- Both commands pass all source gates and full record_hygiene.
- The generated-C bracket gate passes: 155 required, 1024 supplied.
- This updated note passes explicit record_hygiene.

The source gates are gc_roots, dup_defs, dead_defs, meth_writes, name_spec,
rx_caps, ns_names and name_len, plus the binary's errno registration check.
Binary SHA-256: b93bfd0ace8966c3f1de1e79a2feb942b172ee134e8f1e706e52743b36478098.
No full unit suite or Rails component suite was run; no workflow is changed.

The review's optional NoMethodError message wording is recorded as a
follow-up. The exception class and the super lookup correction match Ruby;
this PR does not claim to match that remaining message text.

## R2: completed acceptance

Replacing Module attr/attr_reader/attr_writer/attr_accessor no longer lets super
resurrect the replaced builtin. This refresh merges main 83bc5735 and retains the
reviewed lookup correction. Corpus 1107 covers native helpers through prepend,
replacement, NoMethodError and a previously retained native alias.

Fresh local acceptance uses clean Ruby 4.0.10 through tools/ref_ruby.sh. The two full
sweeps use the same freshly built O2 candidate, with hash indexing ON and OFF.

- `sh run_corpus.sh --both`: **1006/1006 PASS**, exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: **1006/1006 PASS**, exit 0.

Focused corpus 1107 matches the reference on both engines (stdout, stderr and exit
status). Related original CRuby selections are run unchanged, one file at a time,
against the exact matching main 83bc5735. Every invocation uses `MERE_RUBY_GC_TIGHT=1`
and parsed `--seed=1`. The selected test counts below do not claim whole-file or
full-suite passes.

| Original selection | Ruby 4.0.10 | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | --- | --- | --- | --- | --- |
| ruby/test_module.rb (5 selected) | 5 / 34 PASS | 5 / 34 PASS | 5 / 34 PASS | 5 / 34 PASS | 5 / 34 PASS |
| ruby/test_method.rb (15 selected) | 15 / 72 PASS | 15 / 72 PASS | 15 / 72 PASS | 15 / 72 PASS | 15 / 72 PASS |

RSS values below are measured maximum resident set sizes of the test driver from
`/usr/bin/time -l`, in bytes.

| Max RSS bytes, same selections | Reference | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| ruby/test_module.rb (5 selected) | 23576576 | 168624128 | 168820736 | 197083136 | 197033984 |
| ruby/test_method.rb (15 selected) | 22822912 | 162594816 | 162316288 | 179617792 | 179699712 |

Candidate O2 SHA-256:
`f8e628fbbdfbe9033da6e41269cfe551915487389c14ed65492824b365511bfa`. Matching-main
control: 83bc573585b0e73c3266edd2f30fd7d80c2391eb. Compiler 9dec2ff6, mgz 661a01d8.

The optional NoMethodError message wording remains recorded as a nonblocking follow-up;
the exception class and super lookup match Ruby.

Source gates (gc_roots, dup_defs, dead_defs, meth_writes, name_spec, rx_caps, ns_names,
name_len, plus iv_door where present), generated-C bracket depth, full/explicit
completed record_hygiene and staged/unstaged whitespace: PASS. Code/integration and the
completed loop record are pushed together. No full unit/Rails suite, reference gem
installation or workflow change.
