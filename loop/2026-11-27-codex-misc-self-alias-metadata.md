# A1: self-alias visibility and redundant metadata copying

Start from current origin/main 410c231433bebbc3a3f243289c6e2b9d2f0a888c.
Reference: clean Ruby 4.0.10 through tools/ref_ruby.sh. Record the cause
before changing implementation.

| Cause | Ruby 4.0.10 | Main evaluator / VM |
| --- | --- | --- |
| Aliasing a private/protected method to its own name clears source visibility before reading it. | Both visibilities survive. | Both become public. |
| Self-aliasing an inherited method with a public visibility override reads the override after creating the destination entry. | The alias stays public. | It becomes private. |
| An owned self-alias copies its unchanged body and metadata back into the same slots. | Preserve method identity, closure, scope, hooks and alias warning rules. | Rewrites body and metadata and invalidates caches unnecessarily. |

The unchanged Alias resource test still times out on pinned main on both
engines. Its 500 x 1,000 definition/alias/removal workload and original
timeout must remain intact. A timing failure does not establish a leak.

Capture effective source visibility before any destination mutation. An
owned, identical-name alias can retain its existing method/metadata, but
must still mark alias sharing and invoke method_added. Inherited, prepended
and builtin sources require the normal copy path. Verify reference hooks,
Method snapshots, lexical closure, super, visibility and warnings first.
Reference additionally preserves an explicitly public initialize on an
owned self-alias; creating an inherited alias still makes it private.
The existing-name optimization must retain that distinction.
Then compare originals on matching main and both candidate engines,
measure tight-GC RSS with parsed --seed=1, run both full corpus sweeps and
source/completed-record gates before publication. No full unit/Rails suite,
workflow change or reference gem installation.

## Completed R1 acceptance completed acceptance

Self-aliasing preserves the source method visibility, including private/protected
methods and an inherited public visibility override. For an owned identical-name alias,
unchanged body/closure/scope metadata is retained while alias-sharing warning state and
method_added still run. An explicitly public owned initialize stays public, as in Ruby.
Inherited, prepended and builtin sources keep their normal copy path. The original
resource timeout remains unresolved; this PR fixes correctness and avoids redundant
metadata writes.

Fresh local acceptance uses clean Ruby 4.0.10 through tools/ref_ruby.sh. The two full
sweeps use the same freshly built O2 candidate, with hash indexing ON and OFF.

- `sh run_corpus.sh --both`: **995/995 PASS**, exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: **995/995 PASS**, exit 0.

Focused corpus 1136 matches the reference on both engines (stdout, stderr and exit
status). Related original CRuby selections are run unchanged, one file at a time,
against the exact matching main 410c2314. Every invocation uses `MERE_RUBY_GC_TIGHT=1`
and parsed `--seed=1`. The selected test counts below do not claim whole-file or
full-suite passes.

| Original selection | Ruby 4.0.10 | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | --- | --- | --- | --- | --- |
| ruby/test_alias.rb (8 selected) | 8 / 19 PASS | 8 / 19 PASS | 8 / 19 PASS | 8 / 19 PASS | 8 / 19 PASS |
| ruby/test_alias.rb (1 selected) | 1 / 3 PASS | 1 / 0, 0 failures, 1 errors | 1 / 0, 0 failures, 1 errors | 1 / 0, 0 failures, 1 errors | 1 / 0, 0 failures, 1 errors |

RSS values below are measured maximum resident set sizes of the test driver from
`/usr/bin/time -l`, in bytes.

| Max RSS bytes, same selections | Reference | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| ruby/test_alias.rb (8 selected) | 22413312 | 162807808 | 163037184 | 163397632 | 161333248 |
| ruby/test_alias.rb (1 selected) | 22233088 | 247119872 | 212910080 | 233619456 | 228720640 |

Cost measurements use three alternating main/candidate O2 pairs, tight GC and parsed
--seed=1. Instructions and elapsed seconds are medians; RSS is the maximum of three
runs. Elapsed time is diagnostic under shared-machine load.

| Workload / engine | Instruction change | Main / candidate median seconds | Main / candidate max RSS bytes |
| --- | ---: | --- | --- |
| plain / evaluator | -0.093% | 0.414438 / 0.406449 | 84000768 / 84131840 |
| owned / evaluator | -15.969% | 0.139142 / 0.144011 | 78151680 / 72105984 |
| churn / evaluator | +0.009% | 0.645945 / 0.615237 | 86425600 / 86343680 |
| plain / VM | -0.147% | 0.475936 / 0.418925 | 85164032 / 85147648 |
| owned / VM | -15.880% | 0.165496 / 0.139545 | 78708736 / 73056256 |
| churn / VM | -3.134% | 0.750932 / 0.650144 | 92667904 / 88850432 |

Candidate O2 SHA-256:
`61cd87c2324a702c0e4bc351cccce4229f9667166ea977847d7859900354c793`. Matching-main
control: 410c231433bebbc3a3f243289c6e2b9d2f0a888c. Compiler 9dec2ff6, mgz 661a01d8.

Original ruby/test_alias.rb test_alias_memory_leak is unchanged: 500 x 1000
define/alias/remove operations, original timeout and memory assertions. Reference passes
1 test / 3 assertions; matching main and candidate both time out on evaluator and VM.
This is still an open throughput RED, not a leak diagnosis or a claimed resource-test
fix. The separate plain/owned/churn 10000-iteration benchmarks are diagnostics, never
substitutes for that original case. Corpus 1136 has 10 reference-matched rows including
visibility, hooks, Method snapshots, closures, super/prepend, native aliases, public
initialize and warning behavior.

Eight source gates (gc_roots, dup_defs, dead_defs, meth_writes, name_spec, rx_caps,
ns_names, name_len), generated-C bracket depth, full/explicit completed record_hygiene
and staged/unstaged whitespace: PASS. Code/integration and the completed loop record are
pushed together. No full unit/Rails suite, reference gem installation or workflow
change.
