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

Full run_corpus.sh --both, its MERE_RUBY_VM=1 run, source gates, bracket
depth and record_hygiene remain queued. No full-corpus success is claimed
until those runs complete. No full unit suite or Rails component suite
was run. No workflow changes.
