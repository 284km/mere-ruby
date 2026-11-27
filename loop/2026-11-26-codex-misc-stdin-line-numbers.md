# A2: standard input line numbers

Start from current main f4303e14. Before implementation, an unchanged
semantic probe against clean Ruby 4.0.10 confirms both engines lack
STDIN.lineno and lineno=. This breaks error_highlight ATTRASGN_3 before
its intended conversion error can be raised.

| Cause | Main, evaluator and VM | Ruby 4.0.10 |
| --- | --- | --- |
| Native standard input bypasses IO line state | NoMethodError for both readers | Per-stream count, C-int conversion, original assignment return value. |

Preserve closed/readability checks before conversion, independent ARGF and
stream counters, and real exception metadata. Reference io.c increments
ARGF's counter when reading its current input; direct reads otherwise put
the stream counter in $. The ARGF wrapper must retain its pre-read count.
Validate original IO, ARGF and error_highlight selections, both corpus
engines, gates and tight-GC fixed-seed RSS before publication.

## Completed focused acceptance

Corpus 1126 now runs three isolated stdin children without an Open3
prerequisite. All 22 output rows, stderr and status match clean Ruby on
both engines. Controls include Float assignment's original return value,
separate stream/ARGF counters, manually assigned $., closed/unreadable
priority, C-int bounds, per-yield counters, readlines, custom separators,
EOF stability, and object coercion's original return value.

Ordinary O2 SHA-256:
`216425c99326b4b7c479725409a3fb4d908d8db35a4f898c1266ca6b427e4556`.
The unchanged related CRuby files were checked one at a time against
reference, matching main f4303e14 and both candidate engines. Seed 1,
MERE_RUBY_GC_TIGHT=1, /usr/bin/time -l maximum RSS bytes:

| Original file | Phase | Engine | Max RSS | Outcome |
| --- | --- | --- | ---: | --- |
| `error_highlight/test_error_highlight.rb` | ref | evaluator | 33046528 | 1 tests, 8 assertions, 0 failures, 0 errors, 0 skips |
| `error_highlight/test_error_highlight.rb` | main | evaluator | 242958336 | 1 tests, 2 assertions, 1 failures, 0 errors, 0 skips |
| `error_highlight/test_error_highlight.rb` | main | VM | 249856000 | 1 tests, 2 assertions, 1 failures, 0 errors, 0 skips |
| `error_highlight/test_error_highlight.rb` | candidate | evaluator | 304103424 | 1 tests, 8 assertions, 0 failures, 0 errors, 0 skips |
| `error_highlight/test_error_highlight.rb` | candidate | VM | 319209472 | 1 tests, 8 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_io.rb` | ref | evaluator | 27607040 | 3 tests, 24 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_io.rb` | main | evaluator | 197869568 | 3 tests, 24 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_io.rb` | main | VM | 233144320 | 3 tests, 24 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_io.rb` | candidate | evaluator | 197771264 | 3 tests, 24 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_io.rb` | candidate | VM | 231456768 | 3 tests, 24 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_argf.rb` | ref | evaluator | 23494656 | 1 tests, 26 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_argf.rb` | main | evaluator | 175095808 | 1 tests, 26 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_argf.rb` | main | VM | 176226304 | 1 tests, 26 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_argf.rb` | candidate | evaluator | 174555136 | 1 tests, 26 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_argf.rb` | candidate | VM | 178356224 | 1 tests, 26 assertions, 0 failures, 0 errors, 0 skips |

ErrorHighlight selects args_ATTRASGN_3; IO selects set_lineno, set_lineno_gets
and set_lineno_readline; ARGF selects test_lineno. All candidate/reference
selections pass; main fails the original missing-STDIN-setter highlight.
Both full evaluator/VM corpus sweeps pass 965/965 programs with the hash
index ON/OFF, exit 0, using the immutable O2 binary recorded above.
Eight source gates, generated-C bracket depth, full/explicit completed
record hygiene and staged/unstaged whitespace checks pass.
No whole unit suite, Rails component suite, reference gem installation or
workflow change. The earlier Open3 fixture failure was a harness dependency,
not an accepted comparison; the final fixture uses existing popen/file APIs.

## Historical R3 attempt: own-consumption accounting

The direct-STDIN review regression is reproduced by suspending two readers
before feeding A and then B. R3 carries a native (result, own consumed-line
count) tuple instead of a shared before/after consumption delta. It fixes
the direct case, but the extra current-file ARGF control rejects R3: the
reference uses a different entry/exit IO-line delta for ARGF. R3's binary
is private rejected evidence, with no accepted marker or full-corpus run.
The R4 correction and completed acceptance below supersede that attempt.

## R4: preserve CRuby's distinct current-file ARGF accounting

The staged R3 reference probe has 42 rows. Direct STDIN gets/readline
finishes at IO.lineno == $. == 2. With ARGF.file == STDIN, Ruby 4.0.10
finishes at IO.lineno == 2 and ARGF.lineno == $. == 3. The latter follows
io.c rb_io_getline_1: snapshot the IO line number before the suspended
read and add its entry/exit difference to the current-file ARGF counter.

R3 correctly fixes direct STDIN but its stricter per-call ARGF increment
produces 2 in that additional affinity control, unlike the reference. Its
focused check rejects that difference; no R3 full corpus was admitted and
the R3 candidate remains private evidence. Keep each call's own consumed
count for IO.lineno, and retain a separate IO entry snapshot only for
CRuby's ARGF current-file accounting. No fabricated count or timing delay.

R4 focused acceptance completed: all 42 reference rows and related original
CRuby selections pass on both engines. Its three-pair diagnostic reports
gets instruction overhead of +1.657% evaluator / +1.550% VM. No full R4
corpus was admitted; the following R5 removes the now-unused old counter.

## R5: completed acceptance

STDIN line-number readers and setters now track completed line reads. The review
correction removes the obsolete shared physical counter and carries each individual
read's consumed-line count back from the read operation, so a suspended reader cannot
count another thread's line a second time. This merges main 83bc5735. Staged two-reader
gets/readline cases wait for both readers to suspend, send A, wait for its completed
read, then send B; direct STDIN finishes at 2. With ARGF.file == STDIN, IO.lineno
finishes at 2 while ARGF.lineno and $. finish at 3, matching CRuby rb_io_getline_1: its
current-file ARGF accounting retains the IO entry/exit snapshot separately from each
invocation consumption count. The fixture also retains separator, EOF, setter/coercion,
readlines and non-line-read controls.

Fresh local acceptance uses clean Ruby 4.0.10 through tools/ref_ruby.sh. The two full
sweeps use the same freshly built O2 candidate, with hash indexing ON and OFF.

- `sh run_corpus.sh --both`: **1006/1006 PASS**, exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: **1006/1006 PASS**, exit 0.

Focused corpus 1126 matches the reference on both engines (stdout, stderr and exit
status). Related original CRuby selections are run unchanged, one file at a time,
against the exact matching main 83bc5735. Every invocation uses `MERE_RUBY_GC_TIGHT=1`
and parsed `--seed=1`. The selected test counts below do not claim whole-file or
full-suite passes.

| Original selection | Ruby 4.0.10 | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | --- | --- | --- | --- | --- |
| error_highlight/test_error_highlight.rb (1 selected) | 1 / 8 PASS | 1 / 2, 1 failures, 0 errors | 1 / 8 PASS | 1 / 2, 1 failures, 0 errors | 1 / 8 PASS |
| ruby/test_io.rb (3 selected) | 3 / 24 PASS | 3 / 24 PASS | 3 / 24 PASS | 3 / 24 PASS | 3 / 24 PASS |
| ruby/test_argf.rb (1 selected) | 1 / 26 PASS | 1 / 26 PASS | 1 / 26 PASS | 1 / 26 PASS | 1 / 26 PASS |

RSS values below are measured maximum resident set sizes of the test driver from
`/usr/bin/time -l`, in bytes.

| Max RSS bytes, same selections | Reference | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| error_highlight/test_error_highlight.rb (1 selected) | 33275904 | 236666880 | 276250624 | 238288896 | 290521088 |
| ruby/test_io.rb (3 selected) | 27213824 | 188628992 | 188186624 | 225165312 | 224968704 |
| ruby/test_argf.rb (1 selected) | 23232512 | 166068224 | 166100992 | 168574976 | 168607744 |

Cost measurements use three alternating main/candidate O2 pairs, tight GC and parsed
--seed=1. Instructions and elapsed seconds are medians; RSS is the maximum of three
runs. Elapsed time is diagnostic under shared-machine load.

| Workload / engine | Instruction change | Main / candidate median seconds | Main / candidate max RSS bytes |
| --- | ---: | --- | --- |
| gets / evaluator | +1.327% | 0.153256 / 0.173047 | 72761344 / 73170944 |
| readlines / evaluator | +0.157% | 0.160990 / 0.149481 | 76382208 / 76398592 |
| read / evaluator | +0.214% | 0.140755 / 0.133857 | 72171520 / 72286208 |
| gets / VM | +1.539% | 0.188253 / 0.208978 | 73990144 / 74383360 |
| readlines / VM | +0.326% | 0.151036 / 0.176185 | 77529088 / 77578240 |
| read / VM | +0.031% | 0.130116 / 0.142116 | 73138176 / 73187328 |

Candidate O2 SHA-256:
`879d97d66ad831f1f0c0302f8f534c146b86d47db3d4b71cc447dd7cfbd46ba6`. Matching-main
control: 83bc573585b0e73c3266edd2f30fd7d80c2391eb. Compiler 9dec2ff6, mgz 661a01d8.

The error_highlight main selection stops at its failing second assertion, while the
candidate executes all eight assertions. Its RSS comparison therefore includes different
completed work; the passing IO/ARGF selections provide matching-work controls. Tracking
the STDIN stream line number adds the reported gets instruction cost; no zero-overhead
claim is made. Each stdin benchmark reads the same 10000-line, 20000-byte input.

Source gates (gc_roots, dup_defs, dead_defs, meth_writes, name_spec, rx_caps, ns_names,
name_len, plus iv_door where present), generated-C bracket depth, full/explicit
completed record_hygiene and staged/unstaged whitespace: PASS. Code/integration and the
completed loop record are pushed together. No full unit/Rails suite, reference gem
installation or workflow change.
