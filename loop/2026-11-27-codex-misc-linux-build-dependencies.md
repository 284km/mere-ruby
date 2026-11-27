# Verified Linux native dependency setup

A Linux CI runner stopped at apt-get update when an unrelated image-provided package
repository rejected its index. Probe the actual compiler, headers, linker and runtime
first. If an update fails, attempt ordinary authenticated installation of the required
packages and require the real probe to pass. Installation, metadata, compiler and
runtime failures still fail the job.

Add --with-gem-libraries to the helper so the native-gem job checks OpenSSL, libxml2,
libxslt and SQLite through a real C executable, then replace that job's separate apt
block with the helper. A ready toolchain performs no package download.

The helper regression checks pass: 12 tests, 0 failures/errors, including the existing
real compiler and bad-header controls. A real Ubuntu 24.04 arm64 container also passes
after a real authenticated Ubuntu index refresh followed by an injected unrelated update
failure (exit 100), actual package installation and native link/run checks. Repeating
both ready modes makes no further apt calls. Verified versions: OpenSSL 3.0.13, libxml2
2.9.14, libxslt 1.1.39, SQLite 3.45.1, clang 18.1.3. No host packages or reference Ruby
gems were installed.

This PR is stacked on https://github.com/284km/mere-ruby/pull/379, exact head
`069a47b03ac51dae9f57543920053a0f4d073b88`. Its implementation/runtime, complete corpus
and harness inputs are byte-identical to that parent; only the CI dependency
helper/checks, workflow and this loop record differ. The fresh parent acceptance below
is explicitly reused with the same O2 binary. These are not claimed as additional
independent sweeps. The related CRuby/main comparisons and tight-GC fixed-seed max RSS
also come from that exact runtime parent.

Clean Ruby 4.0.10 through `tools/ref_ruby.sh`; matching main
`ad289755a37de94e5faddf61763d49edda849c03`. Corpus 1138 matches stdout, stderr and exit
status in all four engine/index configurations, including ordinary user Proc rejection
and clock argument errors.

- `sh run_corpus.sh --both`: **1027/1027 PASS**, exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: **1027/1027 PASS**, exit 0.

Both sweeps use the same O2 candidate and compare hash indexing ON and OFF.

The following original CRuby files were each run in full, one file at a time, unchanged,
with parsed `--seed=1` and `MERE_RUBY_GC_TIGHT=1`. No full unit or Rails component suite
was run.

| Original full file | Ruby 4.0.10 | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | --- | --- | --- | --- | --- |
| net/http/test_http.rb | 85 / 467 PASS | 85 / 465, 1 failure | 85 / 467 PASS | 85 / 465, 1 failure | 85 / 467 PASS |
| net/http/test_https.rb | 17 / 42 PASS | 17 / 40, 1 failure | 17 / 42 PASS | 17 / 40, 1 failure | 17 / 42 PASS |
| test_timeout.rb | 35 / 90 PASS | 35 / 87, 1 failure | 35 / 90 PASS | 35 / 87, 1 failure | 35 / 90 PASS |

RSS is the measured test-driver maximum from `/usr/bin/time -l`, in bytes. Main stops
assertions in one failing Ractor case in each file; candidate/reference complete those
assertions. The HTTP driver RSS increase is reported rather than presented as an
equal-work memory improvement.

| Driver max RSS bytes | Reference | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| net/http/test_http.rb | 171540480 | 876380160 | 955678720 | 991772672 | 829063168 |
| net/http/test_https.rb | 38060032 | 538968064 | 546521088 | 557989888 | 564559872 |
| test_timeout.rb | 23232512 | 156286976 | 156286976 | 156205056 | 156073984 |

Ordinary clock hot-path cost: three alternating matching-main/candidate pairs, 10000
clock_gettime calls per invocation, O2, tight GC and parsed --seed=1. Instructions and
elapsed seconds are medians; RSS is the maximum of three. Wall time is diagnostic on the
shared machine.

| Engine | Instruction change | Main / candidate seconds | Main / candidate max RSS bytes |
| --- | ---: | --- | --- |
| Evaluator | -0.443% | 0.471069 / 0.410326 | 75448320 / 75677696 |
| VM | -0.139% | 0.461144 / 0.434549 | 76660736 / 76808192 |

Candidate O2 SHA-256:
`557e113c8ed35600fc79a1afa20cdc1667642172a31fc007e83fcae1bc182db8`. Compiler 9dec2ff6;
mgz 661a01d8.

Fresh source gates gc_roots, dup_defs, dead_defs, meth_writes, iv_door, name_spec,
rx_caps, ns_names, name_len, generated-C bracket depth, full and explicit completed
record_hygiene, and staged/unstaged whitespace: PASS. Code and completed record are
pushed together. This changes .github/workflows/ci.yml and needs the owner's review
before merge.
