# Corpus stderr comparison design

A4 starts with measurement before changing the runner. Baseline main is
751362a3, clean Ruby 4.0.10 through tools/ref_ruby.sh, both evaluator and
VM, with hash indexing enabled and disabled. Baseline program counts,
difference counts and elapsed times are recorded below. The baseline is
a source-pinned snapshot, not a claim about future main revisions.

Capture stderr from the same reference/candidate executions that already
compare stdout and status. Retain warning order and duplicates. Start with
an opt-in warnings check and also offer full normalized stderr comparison;
current differences must be visible rather than globally accepted.
Normalize only known interpreter/source roots, the actual harness temporary
root and object-inspection addresses. Preserve line numbers, warning
text, exception classes, arbitrary hexadecimal literals and repeated lines.
Treat warnings as complete ordered lines containing Ruby's warning prefix.

Batch normalization after the existing loop avoids launching a Ruby/Python
normalizer for every fixture. A JSON report records all-stderr differences
and warning differences separately for each engine and indexing mode,
including reference/candidate stderr and comparison time. No fixture is
silently excluded. Normalized output remains available for review.

The first implementation will be opt-in because any baseline warning gap
needs a cause-specific runtime fix before default enforcement. No .github
workflow is changed; CI adoption needs the owner's review. Meaningful
normalization/checker controls must catch a duplicated warning, changed
text, changed warning line and a newly raised stderr exception, while
accepting only the documented path/address substitutions.

## Measured baseline before fixture canonicalization

Pinned main 751362a3, clean Ruby 4.0.10, 967 programs and both actual hash
index executions: evaluator has four programs with ordered warning-line
differences and seven with full-stderr differences. Capturing all programs
took 839.837 seconds; normalization/comparison itself took 0.248 seconds
(0.501 seconds including checker startup and interpreter path queries).
These are findings, not a passing stderr sweep. VM also has four warning
programs and seven full-stderr programs: capture 809.768 seconds; comparison
0.210 seconds (checker process 0.456 seconds). All 3868 candidate exit-status
comparisons match their reference execution.

| Program | Observed stderr cause |
| --- | --- |
| 343 | An extra forwarding-at-EOL warning. |
| 472 | Regexp warning appends a pattern the reference does not print. |
| 764 | Two historical binary-regexp warnings are missing. |
| 940 | The same 12 warning lines occur in a different order because fixture setup enumerates unordered method names. |
| 190, 642, 645 | Ractor exception reports differ; warning-only mode retains the distinction from full stderr. |

The 940 setup can sort its method names before undefining them. This
canonicalizes an unspecified fixture input rather than sorting or dropping
actual warnings in the checker. Keep ordered comparison and duplicate
counts intact. The complete inventory finished with all 967 source hashes verified before
that one-line fixture change was made. Recheck its actual stdout, stderr and
status in both engines and indexing modes before acceptance.

## Deterministic fixture and checker cost

The one-line change `undef_method(*instance_methods.sort)` fixes the order
of the fixture's method list before it emits warnings. The updated 940
matches actual stdout, stderr and status on both engines with hash indexing
ON/OFF. Replacing only its captures in the saved 967-program manifest leaves
three warning programs (343, 472, 764) and six full-stderr programs differing
on each engine. The checker exits 1 on these real remaining differences.
It still compares warning order and duplicate counts without exclusions.

Actual checker runs over 1934 executions per engine, tight GC and the
measurement wrapper's parsed `--seed=1`:

| Input engine | Comparison seconds | Checker max RSS bytes |
| --- | ---: | ---: |
| Evaluator | 0.615143 | 71057408 |
| VM | 0.616001 | 71778304 |

These runs reuse the original saved captures except the explicitly rerun
940; they do not claim a second whole-corpus capture. Their interpreter and
memory settings differ from the initial baseline timing above. The checker
uses the clean reference Ruby as a host tool for either input engine.

Unchanged original-file controls, separately invoked with tight GC and
`--seed=1`, pass on reference, pinned main and candidate, both engines:
`ruby/test_warning.rb#test_warn_called_only_when_category_enabled`
(1 test / 10 assertions), and `ruby/test_rubyoptions.rb#test_warning`
(1 / 124). Runtime binaries are byte-identical: this change affects the
corpus driver, checker and deterministic fixture setup.

| Max RSS bytes | Reference | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| Original Warning selection | 22183936 | 164773888 | 165134336 | 164724736 | 164626432 |
| Original RubyOptions selection | 26771456 | 191463424 | 191250432 | 196165632 | 197787648 |

The compact JSON companion preserves the initial baseline's seven findings
and records this post-canonicalization measurement separately.

Completed default-runner acceptance: `sh run_corpus.sh --both` and
`MERE_RUBY_VM=1 sh run_corpus.sh --both` each pass 967/967 programs,
hash index ON/OFF, exit 0, using the same immutable O2 SHA above.
The evaluator result uses a complete fresh retry; an initial resource-guard
interruption is retained as an excluded attempt. Eight source gates,
generated-C bracket depth, full/explicit design and JSON record_hygiene,
and staged/unstaged whitespace checks pass. This default stdout/status
acceptance does not turn the measured stderr differences into passes.
No default stderr enforcement or workflow change is included.
