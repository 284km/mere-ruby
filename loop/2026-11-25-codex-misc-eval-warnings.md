# Eval warnings before a trailing syntax error

B9. Base main: fdda9150. Reference: clean Ruby 4.0.10 a704b7cd95.
Compiler: Mere 9dec2ff6, mgz 661a01d8, O2. No reference gems installed.

The top-level eval parser accepted a partial statement list and ignored
a trailing block terminator. As a result it returned a value rather than
raising, and treated the last literal as that eval value instead of a
void-context statement. Check the parser's real remaining token list,
run void-context warning analysis before rejecting it, and use Prism's
actual diagnostic and source positions for the syntax error. This adds
no rescan per literal element.

Corpus 1108 captures child stderr under -W as part of the differential
fixture, with first lines 1 and 7 and a valid subsequent eval. Both
engines match Ruby's stdout, exit status and captured warning lines.

Related unchanged CRuby ruby/test_syntax.rb selections: warn_grouped_expression,
warn_unreachable, warning_literal_in_condition, eval_return_toplevel, and
return_in_BEGIN_in_eval. Each invocation uses --seed=1 and
MERE_RUBY_GC_TIGHT=1. Reference, main and candidate all pass 5 tests and
246 assertions on both engines. Tempfile is preloaded on both sides because
that selected upstream test otherwise depends on an unrelated file
requiring it first; the initial missing-Tempfile run is not an acceptance
result. Max RSS (/usr/bin/time -l, bytes):

| Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| ---: | ---: | ---: | ---: |
| 185942016 | 199000064 | 202932224 | 199327744 |

The final R3 acceptance results below supersede the initial pending sweeps. No full unit suite or Rails component suite
was run. No workflow changes.


## Full-corpus correction: report the ISeq check's original source

The first full evaluator sweep stopped at corpus 664: ISeq.compile of a
stray end exposed the internal __eval_trailing_tokens__ reason instead of
Prism's diagnostic. That attempted sweep failed and is not acceptance.
The ISeq syntax check inserts a BEGIN line into a temporary source; its
existing special handling bypassed the new trailing-token report.

The private parse-only wrapper now supplies the original source separately.
A trailing-token refusal reports Prism errors against that source and its
actual starting line. Ordinary eval uses its own source. No location is
invented and no wrapper is detected by searching user source text.
The wrapper's normal ISeq execution path retains its default nil argument.

Corpus 1108 adds ISeq.compile of end, leading comments, a multiline literal
prefix and a comment containing the wrapper's spelling, at lines 1 and 7.
All 47 output lines match clean Ruby on evaluator and VM, including child
warnings and status. Corpus 664 also matches all 27 lines, stdout/stderr
and status, on both engines with tight GC.

The final ordinary O2 R3 binary SHA-256 is
89cdf66617300a2fe6e8dbee2b04bab51e264d289afa763a2ab7539b7867c4f9,
using unchanged Mere 9dec2ff6 and mgz 661a01d8 pins. The generated-C
bracket gate passes, 155 required / 1024 supplied.

Related unchanged files are repeated separately with --seed=1 and tight
GC, compared with main a9e68981. test_syntax uses the same Tempfile preload
on reference, main and candidate, retaining all 246 assertions. An initial
run without that upstream prerequisite errors on all three and is not
acceptance. The test_iseq selection passes on all three; its reference
assertion count is 12 and both main/candidate counts are 13, preserved here.

| File | Reference | Main evaluator / VM | R3 evaluator / VM |
| --- | --- | --- | --- |
| test_syntax.rb selections | 5 tests / 246 assertions / pass | same, both | same, both |
| test_iseq.rb selections | 4 tests / 12 assertions / pass | 4 / 13 / pass, both | same as main |

The ISeq selection covers syntax_error_message, compile_error,
compile_file_error and unreachable_syntax_error. Max RSS is bytes:

| File | Main evaluator | R3 evaluator | Main VM | R3 VM |
| --- | ---: | ---: | ---: | ---: |
| test_syntax | 201359360 | 209305600 | 204963840 | 203997184 |
| test_iseq | 226721792 | 223444992 | 229556224 | 225017856 |

Fresh R3 full evaluator/VM corpus sweeps and the source gates pass, as
recorded below. The correction, expanded corpus and completed record are
kept in one push. No full unit or
Rails component suite was run and no workflow is changed.

The first R3 full sweep encountered local disk exhaustion while writing
comparison files. That whole attempt is discarded, including any ok lines
printed after shell redirection errors. Its diagnostic log is preserved
separately; no completed acceptance is taken from it. Capacity recovered
before a fresh run. The external runner now checks available capacity and
rejects any shell disk-write error even if a comparison command returns 0.
Both fresh runs complete successfully: run_corpus.sh --both and
MERE_RUBY_VM=1 run_corpus.sh --both each pass 884/884 with hash indexing
ON and OFF. All eight source gates and the full record_hygiene pass in
each run. The generated-C bracket gate passes at 155 / 1024.
Explicit completed-loop-note record_hygiene passes (1 file).
Neither fresh log contains a disk-write error.

Only one corpus sweep from this session runs at a time. Future heavy jobs
reserve a shared admission slot after counting other sessions, with a
machine-wide limit of two and a capacity check before starting.
