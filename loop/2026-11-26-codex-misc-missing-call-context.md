# A2: native missing-method exception context

Branch starts from current main 85da98fb. Before changing implementation,
clean Ruby 4.0.10 and the pinned main 8f412f51 diagnostic reproduce these
runtime differences on both engines. This record precedes the fix.

| Cause | Reference | Main | Scope |
| --- | --- | --- | --- |
| Native missing [] loses method metadata | NoMethodError.name is :[]; args and receiver retained | name is nil | Preserve the native failure call context; related error_highlight index/operator-write spots. |
| Bare call on primitive self | NameError | NoMethodError on nil/String | Separate implicit-self dispatch cause, PR #343. |
| Class + Integer | NoMethodError | TypeError | Separate operator dispatch cause, PR #338. |

The first cause is a native refusal using prim_raise instead of the existing
metadata-bearing missing-method path. Actual parser ranges are available;
no invented source position or backtrace-node selection is proposed here.
The same native refusal exists for size/length, empty?, to_i, to_f and to_a.
Compare their metadata and unchanged upstream error_highlight selections on
both engines. Any remaining frame-location difference is recorded separately.
The completed corpus, source gates, hygiene and fixed-seed tight-GC RSS
comparisons are recorded below. No full suite or workflow changes.


## Completed focused acceptance

Corpus 1123 matches all 14 output rows, stderr and status against clean
Ruby 4.0.10 on evaluator and VM. The unchanged error_highlight file's
seven index/operator-write cases now pass 7 tests / 50 assertions on both
engines and the reference; pinned main 03694405 fails all seven after
20 assertions. No position heuristic or parser location was changed. The
actual exception name now allows error_highlight to select the correct
operation within the real existing Prism node. The unchanged Exception
message-of-NameError case passes 1 test / 3 assertions on all five phases.

All invocations use MERE_RUBY_GC_TIGHT=1 and --seed=1, one file at a time.
Max RSS bytes from /usr/bin/time -l:

| File | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: |
| error_highlight selections | 388513792 | 374521856 | 512770048 | 411402240 |
| ruby/test_exception selection | 176291840 | 178192384 | 180043776 | 178749440 |

Ordinary O2 candidate SHA-256: 8e8f0166e6ecac83578ca062733442def27b5bc6d09f6403fb392e82ab58a1b8.
Compiler 9dec2ff6, mgz 661a01d8; tools/ref_ruby.sh selects the clean
reference. The candidate starts from main 85da98fb; the older pinned main
control is named above rather than presented as a matching-base build.
Both full corpus sweeps pass 962/962 programs, hash index ON/OFF, exit 0:
`sh run_corpus.sh --both` and `MERE_RUBY_VM=1 sh run_corpus.sh --both`.
Both binary proofs match the immutable O2 SHA above. Eight source gates,
generated-C bracket depth, full/explicit completed record hygiene and
staged/unstaged whitespace checks pass. Other A2 causes are independent
and are not claimed fixed.
