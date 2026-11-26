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

The final integration uses main 4b31ea2c. Ruby's CLI appends a newline to
every -e fragment; the SyntaxError report now uses that actual input before
calling the real detailed_message hook. This preserves the full Prism
diagnostic order and a user's single #message invocation. No diagnostic
locations, counts or ordering are manufactured.

## Completed focused acceptance and memory measurements


The real CLI newline corrects the diagnostic-order difference: expanded
corpus 1109 matches all 18 rows and corpus 445 all 23 rows on both engines,
including stdout, stderr and exit status. Controls retain explicit final
newlines and verify that a custom detailed_message calls #message once.
Neither failed r10 nor r11 is presented as an accepted revision.

Unchanged upstream files, reference/main 03694405/candidate on both engines:
ruby/test_exception.rb SyntaxError path/detailed_message selections pass
2 tests / 11 assertions; ruby/test_module.rb method_defined selections
pass 3 tests / 339 assertions, no failures/errors/skips in all phases.
Max RSS bytes with MERE_RUBY_GC_TIGHT=1, fixed --seed=1, /usr/bin/time -l:

| File | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: |
| test_exception | 176586752 | 177209344 | 180207616 | 180486144 |
| test_module | 178601984 | 177602560 | 204816384 | 205619200 |

Ordinary O2 SHA-256: 31654c65ac8c34ba51886878c8b77f3c0390fde1ea0b08487aaa746ba22fae6d.
Mere 9dec2ff6, mgz 661a01d8, merged main 4b31ea2c, clean Ruby 4.0.10
through tools/ref_ruby.sh.

## Completed acceptance

- `sh run_corpus.sh --both`: **956/956 PASS**, hash index ON and OFF.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: **956/956 PASS**, hash index ON and OFF.
- Both full sweeps used the same r12 binary and source tree as the focused checks.
- Eight source gates PASS: gc_roots, dup_defs, dead_defs, meth_writes,
  name_spec, rx_caps, ns_names and name_len.
- Generated-C bracket depth PASS: 155 required / 1024 supplied.
- Full record_hygiene and explicit completed-loop record_hygiene PASS.
- Whitespace checks PASS for both staged and unstaged changes.

No full unit-test suite or Rails component suite was run. No workflow is
changed by this PR. The code correction, integrated main, expanded fixture
and this completed record are submitted in one push after local acceptance.
