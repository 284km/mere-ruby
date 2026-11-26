# A1: current-main numeric RED reproduction and causes

The merged inventory PR #243 records the archived report before fixes.
This branch starts from current origin/main a63e47c3. The clean reference
is Ruby 4.0.10 a704b7cd95. All selections below use unchanged upstream
files, one file at a time, --seed=1 and MERE_RUBY_GC_TIGHT=1.

The actual ext/-test-/integer C sources were built separately against the
reference headers and Mere C API headers, outside the reference install.
No helper is replaced and no reference gems are installed. A direct
reference probe confirms to_bignum(0) is a real forced Bignum.

The selected test_bignum.rb cases pass 8 tests / 60 assertions on Ruby;
main fails all 8 on evaluator and VM (34 assertions reached). Selected
test_integer.rb#test_pow passes 1 test / 36 assertions on Ruby; main times
out at its existing test deadline on both engines (6 assertions reached).
No deadline, budget, assertion or test size was changed.

| Case | Both main engines | Cause / disposition |
| --- | --- | --- |
| test_aref2 | Fails negative-width read, expected shifted Bignum but got 1 | Integer bit-slice width semantics; separate cause. |
| test_convert | ArgumentError instead of RangeError | Radix conversion loses C-int overflow check; separate cause. |
| test_digits_for_invalid_base_numbers | Negative Bignum base is accepted | Builtin radix sign validation; separate numeric cause. |
| test_divide | Missing out-of-Float-range warning | Explicit Bignum conversion warning; separate cause. |
| test_float_fdiv | Finite 1e300 quotient becomes Infinity | Integer receiver is converted before Float division; fix in this PR. |
| test_interrupt_during_to_s | Expected thread.raise is not delivered during conversion | Scheduler interrupt boundary; investigate separately. |
| test_to_f | Missing out-of-Float-range warning | Same conversion-warning cause as test_divide. |
| test_to_s2 | ECHILD instead of RangeError | Process wait flags lose C-int overflow check; investigate with integer argument conversion. |
| test_pow | Existing per-test timeout after 6 assertions | Huge negative exponent work/interrupt path; investigate separately. |

## First cause: overflowing Integer receiver in fdiv

CRuby first converts the receiver; when that overflows, its fdiv path
converts the Float divisor to its exact binary fraction and divides the
integer magnitudes. It does not divide Infinity by the divisor. The
reference also raises ZeroDivisionError for a zero Float divisor and
FloatDomainError for an infinite divisor on this overflow path, while
preserving NaN. These controls were reproduced before editing.

Implementation, corpus and final acceptance are recorded below after
validation. The other numeric causes in the table remain separate work.

The invalid-digits-base failure was checked at its exact assertion line
840: it is the ordinary negative Bignum base, not the earlier forced-small
Bignum controls. A standalone n.digits(-n), n = 2**1024 - 1, also fails
without any C API helper. This case stays in the numeric work stream.

## fdiv implementation and focused acceptance

The final O2 helper keeps the ordinary finite-receiver conversion path.
When an Integer's private Float conversion overflows, it decomposes a
finite Float divisor into its exact binary fraction and uses the existing
integer-magnitude quotient routine. It preserves NaN and the reference's
overflow-path errors for zero and infinite divisors. Both primitive entry
paths share the helper; no Ruby conversion hook is called for a builtin
Float, and no global receiver or cache is added.

Corpus 1113 covers positive/negative receivers and divisors, finite and
overflowing results, Float::MAX, signed zero, infinities, NaN, ordinary
finite conversion, integer-pair division, coercion and a saved native alias.
Its complete stdout and exit status match clean Ruby on evaluator and VM
with tight GC, on the final O2 binary.

The following unchanged upstream selections were run one file at a time,
with seed 1 and tight GC. Reference and candidate pass all rows; main's
bignum selection retains the one recorded float_fdiv failure. RSS is bytes:

| File / selection | Main result | Candidate result | Main evaluator RSS | Candidate evaluator RSS | Main VM RSS | Candidate VM RSS |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| ruby/test_bignum.rb, four fdiv tests | 4 / 13, 1 failure | 4 / 13, pass | 179453952 | 178159616 | 179421184 | 179912704 |
| ruby/test_integer.rb, fdiv/obj_fdiv | 2 / 104, pass | 2 / 104, pass | 167329792 | 165969920 | 168886272 | 169050112 |

Build: compiler 9dec2ff6, mgz 661a01d8, ordinary O2. Immutable binary
SHA-256 b85f3c6d04c4978b9ef856952dc76b0fc2b6cfa56fccaff553db709ab77fceb3.
The generated C passes the bracket-depth gate. The full evaluator
`sh run_corpus.sh --both` and subsequent
`MERE_RUBY_VM=1 sh run_corpus.sh --both` are running. They include all
source gates and full record_hygiene; their final results remain pending.
This loop record is also checked explicitly. No full unit suite or Rails
component suite was run, and no workflow is changed.
