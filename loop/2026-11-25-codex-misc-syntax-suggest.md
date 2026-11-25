# B10: bundled syntax_suggest for uncaught SyntaxError

Branch codex-misc-syntax-suggest starts from main fdda9150. Before changing
anything, the clean Ruby 4.0.10 reference was checked: its default loaded
features include syntax_suggest/core_ext.rb, and SyntaxError's
detailed_message method comes from that file (line 11). Disabling
syntax_suggest or disabling gems prevents its annotation.

The runtime now loads the actual bundled syntax_suggest 2.0.3 core
extension at boot when gems and the feature are enabled. Its unchanged
MIT source and actual optparse dependency are embedded by the generator;
the license is preserved. No reference gems are installed. Inherited
Module#method_defined? lookup is corrected so the real extension detects
Exception#detailed_message and takes the intended integration branch.
The CLI honors --disable=syntax_suggest and --disable=gems.

Corpus 1109 compares the complete gem-provided unmatched-pair annotation
and verifies that both disable flags suppress it. It matches Ruby on both
engines. The existing parser diagnostic block after the annotation still
has framing differences; this change does not claim complete byte-for-byte
SyntaxError stderr equivalence. Existing custom detailed_message behavior
is preserved rather than replaced with a forced Prism diagnostic.

## Related unchanged upstream files

| File | Candidate result | Main evaluator RSS | Candidate evaluator RSS | Main VM RSS | Candidate VM RSS |
| --- | --- | ---: | ---: | ---: | ---: |
| ruby/test_exception.rb | 2 tests, 11 assertions, 0 failures, 0 errors, 0 skips | 176111616 | 176766976 | 178192384 | 180076544 |
| ruby/test_module.rb | 3 tests, 339 assertions, 0 failures, 0 errors, 0 skips | 176979968 | 176521216 | 203948032 | 206585856 |

## Validation policy

The reference is the clean pinned Ruby 4.0.10. The unchanged upstream
files above run one file at a time, against main and both candidate engines,
with `--seed=1` and `MERE_RUBY_GC_TIGHT=1`. RSS is max resident bytes from
`/usr/bin/time -l`. No gems are installed into the reference.

The O2 binary uses compiler 9dec2ff6 and mgz 661a01d8. Full acceptance is
running sequentially: `sh run_corpus.sh --both`, followed by
`MERE_RUBY_VM=1 sh run_corpus.sh --both`. Each includes gc_roots,
dup_defs, dead_defs, meth_writes, name_spec, rx_caps, ns_names, name_len
and full record_hygiene. Generated C is checked with
`MR_C=mr.c sh tools/bracket_depth_check.sh`; this loop record is also
checked explicitly with record_hygiene. Focused passing cases are not a
substitute for those pending sweeps. No full unit suite or Rails component
suite was run; no workflow is changed.
