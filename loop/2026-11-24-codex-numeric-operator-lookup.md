# Numeric operators stop lookup at their native owner

The branch starts from main `b7fe86e104a9a68ff47a3e0598e14f9177eab3e8`,
with Ruby 4.0.10 as the reference.

The Ruby method table omits native method bodies. A lookup that asked only
whether any ancestor had a Ruby body let Comparable#< override Integer's and
Float's own <, and Numeric#- override Integer's and Complex's own subtraction.
The new numeric lookup walks the real ancestor order and stops at either a
Ruby method or the physical native entry recorded by the existing owner table.
The evaluator, named sends, numeric fast-path eligibility and Complex component
operations use that distinction. Own-class definitions and prepends still win.

Rational's ordering operators belong to Comparable. They now ask a redefined
Rational#<=> before attempting the right operand's coercion. Integer#* with a
Rational operand re-sends to an overridden Rational#* after coercion; the
coerced numeric result honors its Ruby operator. The VM declines its numeric
fast path when these Ruby callbacks must run.

Corpus 984 runs isolated child probes so one scenario's method-table changes
cannot hide another. It covers ancestor additions, Integer and Float own
overrides, prepend, named sends, Rational comparisons including an object whose
coerce must not run, and Integer/Bignum multiplication with Rational. Each child
inherits the selected VM mode.

The focused development comparison matches all 19 output lines on both
engines. Acceptance is measured with ordinary O2 builds on the fixed final
head: full corpus in both hash-index modes, the full VM corpus, source gates,
record hygiene and targeted upstream numeric files against the starting main.
Exact counts are reported in the PR description. No Rails cold measurement or
full upstream unit-test suite is run.
