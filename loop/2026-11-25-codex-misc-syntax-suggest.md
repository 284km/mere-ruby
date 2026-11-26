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

## Current main integration after re-review

The reviewer reported a prospective m_driver conflict. It is resolved
against actual main 89ad241c by using its shaped-ivar iv_set operation
while preserving the real CLI source/report and highlight:false keyword.
The integration is validated by the completed r13 checks below.

The shared origin/main ref advanced after fetch; Git's MERGE_HEAD records
89ad241c. The first new build metadata label of 4920 is corrected in the
provenance record; the binary itself is unchanged. A separately built
exact 89ad241c control was then used for the comparisons below.

Corpus 1109 (18 rows) and 445 (23 rows) match on both engines, stdout,
stderr and exit status. Unchanged CRuby selections all pass on reference,
matching main and candidate, --seed=1: Exception SyntaxError 2 tests /
11 assertions; Module method_defined 3 / 339.

| Tight-GC max RSS bytes | Reference | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| Exception | 23576576 | 171819008 | 172654592 | 176439296 | 176898048 |
| Module | 23511040 | 174686208 | 176816128 | 202932224 | 205258752 |

The 5919-line syntax_suggest/OptionParser bundle regenerates byte for byte
from clean Ruby 4.0.10. Current ordinary O2 binary SHA-256
ac93a4c670d8b9d61e1937db3609f94e4e164c361dd31cd859448b1a24a6f7ff,
compiler 9dec2ff6, mgz 661a01d8. The final r13 sweeps both pass 973/973 with hash indexing ON and OFF;
the earlier 956 counts describe only the historical r12 integration.

## Completed r13 integration acceptance

- sh run_corpus.sh --both: 973/973 PASS, hash index ON and OFF, exit 0.
- MERE_RUBY_VM=1 sh run_corpus.sh --both: 973/973 PASS, ON/OFF, exit 0.
- Both binary proofs match the ac93a4c670d8 O2 binary above.
- All eight source gates, generated-C bracket depth and iv_door PASS.
- Full and explicit completed-loop record_hygiene and whitespace checks PASS.
- Related original-file selections and tight-GC seed-1 RSS are recorded above.

The m_driver conflict is resolved using the actual main shaped-ivar setter.
There is no PR-owned workflow change; workflow updates in the merge are
inherited byte for byte from integrated main. No full unit or Rails suite.

## Follow-up review: ordinary OptionParser loading and boot cost

Ordinary OptionParser loading now tries every real load-path file before
its bundled fallback, including reference fallback directories and a newer
user copy. Physical absolute/relative optparse loads retain their actual
identity, so optparse/time does not execute the parent a second time.
Other native-backed shipped libraries retain their existing selection rule.

The unchanged SyntaxSuggest api.rb requires cli.rb, which requires
OptionParser. The two embedded pure-Ruby dependencies remain a last fallback
for standalone use without an external stdlib. Removing them outright loses
existing standalone SyntaxError annotation; this revision preserves that
behavior while fixing the real-file selection reported in review.

Fresh ordinary O2 builds use pinned main
8b9907bed0f330cf918582054aec34b63f1aeedf, compiler 9dec2ff6 and mgz 661a01d8.
Main SHA-256 f5d08342fa4b1f36c0b96347f8abd128d0f31afd75844e611dd3d84859ae6d69;
candidate abd7eb3d43163308923661cd6cccafe477ad8ce9b8c025b21b1b02a1c8607eaf.
The unchanged 5919-line upstream bundle regenerates byte for byte. Integration
with this pinned main is conflict-free; workflow changes belong to main.

Corpus 1109 now matches all 24 rows on both engines, stdout, stderr and exit
status, including verbose optparse/time, optparse/ac, optparse/kwargs,
relative-first loading, a user copy and a path object. The original 18 rows
continue to check standalone annotation and feature switches. Corpus 445
also matches all 23 rows on both engines.

An exploratory path-object counter records a separate existing difference:
Ruby 4.0.10 calls to_path twice; exact main and candidate call it once on
both engines. All select the actual user library with empty stderr. The
committed case checks library selection; a separate five-phase probe keeps
the exact counter results. No runtime change forces extra conversions.

Unchanged original CRuby selections, --seed=1, all pass on reference,
pinned main and candidate, both engines: Exception SyntaxError 2 tests /
11 assertions; Module method_defined 3 / 339.

| Tight-GC max RSS bytes | Reference | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| Exception | 23773184 | 175374336 | 175456256 | 178323456 | 179388416 |
| Module | 23363584 | 175374336 | 176193536 | 203112448 | 203227136 |

Startup measurement runs p 1 after parsing --seed=1 and seeding srand,
MERE_RUBY_GC_TIGHT=1, /usr/bin/time -l, three alternating main/candidate
pairs per engine. RUBYLIB, RUBYOPT and RUBY_BOX are cleared. Instructions
are hardware counts; RSS is the maximum of three runs, in bytes.

| Engine | Main median instructions | Candidate median | Change | Main max RSS | Candidate max RSS |
| --- | ---: | ---: | ---: | ---: | ---: |
| Evaluator | 940983762 | 947117478 | +0.652% | 70909952 | 71712768 |
| VM | 939645620 | 949321880 | +1.030% | 71614464 | 72515584 |

Evaluator instruction ranges are 937397787-977318752 (main) and
945358737-991407823 (candidate); VM ranges 939428436-950808726 and
944738493-954667664. The ranges overlap; the positive medians are reported
as measured overhead. Candidate --disable=syntax_suggest controls have
median instructions 937996661 / 943912662 and max RSS 71057408 / 71827456
for evaluator / VM. Wall times are noisy under shared machine load and
are not used to claim a startup speed improvement.

## Final r14 acceptance

- `sh run_corpus.sh --both`: 984/984 PASS, hash index ON/OFF, exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: 984/984 PASS, ON/OFF, exit 0.
- Both full sweeps verify the same r14 candidate binary SHA-256 above.
- All eight source gates, generated-C bracket depth and iv_door pass.
- Full/explicit completed record_hygiene and staged/unstaged whitespace pass.

No full unit or Rails component suite was run. The actual code correction,
expanded fixture, integrated main and completed record are submitted together
in one push after local acceptance.
