# Declare locals from skipped pattern-case bodies

An assignment in an unexecuted case/in body did not declare its local on the evaluator.
A later branch could therefore assign a block-local variable instead of updating the
method local, or a subsequent read could raise NameError. The VM and Ruby already
preserve these declarations.

Declare skipped guard/body targets before trying the following pattern clause. After an
executed body, also declare its remaining targets and the later branches while
preserving the original return or other control flow. Each body is scanned once;
parsing, pattern-variable binding and deconstruction caching keep their existing paths.

Corpus 1146 covers matching and skipped bodies, a false guard, no-match rescue, nested
assignments, returned Binding objects and textual block-scope ordering. It and corpus
974 match Ruby stdout, stderr and exit status on both engines with the Hash index on and
off (8/8 executions).

Clean Ruby 4.0.10 through tools/ref_ruby.sh; matching-main control and branch base
491cc5cab7e727606e1b00a141607e4742194d0a. Ordinary O2, compiler 9dec2ff6, mgz 661a01d8.

- sh run_corpus.sh --both: **1032/1032 PASS**, exit 0.
- MERE_RUBY_VM=1 sh run_corpus.sh --both: **1032/1032 PASS**, exit 0.

Related unchanged CRuby selection, MERE_RUBY_GC_TIGHT=1 and parsed --seed=1. No complete
unit or Rails component suite was run.

Original selection in ruby/test_pattern_matching.rb:
`/test_(basic|modifier|var_pattern|array_pattern|hash_pattern|single_pattern_error_guard_clause)\z/`.

| Original file / scope | Ruby | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | --- | --- | --- | --- | --- |
| ruby/test_pattern_matching.rb | 6 tests, 130 assertions, 0 failures, 0 errors, 0 skips | 6 tests, 130 assertions, 0 failures, 0 errors, 0 skips | 6 tests, 130 assertions, 0 failures, 0 errors, 0 skips | 6 tests, 130 assertions, 0 failures, 0 errors, 0 skips | 6 tests, 130 assertions, 0 failures, 0 errors, 0 skips |

Measured /usr/bin/time -l maxima in bytes:

| Driver max RSS bytes | Ruby | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| ruby/test_pattern_matching.rb | 22560768 | 157958144 | 157958144 | 188989440 | 188989440 |

Three alternating matching-main/candidate pairs, tight GC and parsed --seed=1. Pattern
executes 10000 real array-pattern matches; plain is 10000 ordinary loop iterations.
Whole-process instructions and seconds are medians; RSS is the maximum of three.

| Engine / workload | Instruction change | Main / candidate seconds | Main / candidate max RSS bytes |
| --- | ---: | --- | --- |
| Evaluator / pattern | +0.453% | 0.192212 / 0.214786 | 85819392 / 85819392 |
| Evaluator / plain | +0.618% | 0.164839 / 0.201684 | 85164032 / 85213184 |
| VM / pattern | +0.127% | 0.220361 / 0.224004 | 86278144 / 86343680 |
| VM / plain | -0.144% | 0.153341 / 0.156096 | 85147648 / 85164032 |

Two independent parser/AST boundaries remain open and are reproduced on the matching
main control. First, eval("defined?(future_local)") before a later assignment returns
nil on the evaluator for both classic if and pattern case, while Ruby and the VM return
"local-variable". This patch repairs the skipped-earlier-branch declaration but does not
eagerly declare later locals, which would change block scope. Second, a literal
assignment in a pattern guard emits Prism's "found '= literal' in conditional, should be
==" warning on Ruby but no warning on either main engine. Dedicated
reference/main/candidate controls retain both differences. Corpus 1146 uses a dynamic
false-valued assignment to test guard declaration independently, and stderr comparison
stays enabled. These existing source-location/diagnostic gaps are follow-ups for the
parser/AST owner.

Candidate O2 SHA-256 a6e51c5de4ace5241d650edcc11764878d1b54fad79ade679c035aaf7a74f633.
No original test, assertion count, workload or resource limit is changed.

Source gates gc_roots, dup_defs, dead_defs, meth_writes, iv_door, name_spec, rx_caps,
ns_names, name_len, generated-C bracket depth, full and explicit completed
record_hygiene, and staged/unstaged whitespace: PASS. Code and completed record are
pushed together. No workflow change or reference gem installation.
