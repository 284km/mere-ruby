# A1: reject negative Bignum digit bases

Branch base: current origin/main a63e47c3. The cause was recorded before
editing in the A1 numeric reproduction table, following merged inventory
PR #243. Unchanged test_bignum.rb#test_digits_for_invalid_base_numbers
fails at line 840 on both main engines against clean Ruby 4.0.10.
That assertion passes an ordinary negative Bignum radix. A standalone
n.digits(-n), n = 2**1024 - 1, reproduces without any C API extension;
main returns [0, -1] instead of raising ArgumentError.

The radix guard checks machine Integers but accepts every Bignum. It now
checks the Bignum sign and the same lower bound before division. Existing
receiver-sign precedence and positive large radices are preserved.
Corpus 1114 covers normal Bignums, converted Float/Rational negative bases,
negative-receiver error precedence, positive huge bases and small controls.

The O2 binary uses Mere 9dec2ff6 and mgz 661a01d8. Corpus 1114 matches
clean Ruby 4.0.10 on evaluator and VM. Each unchanged upstream file runs
separately with --seed=1 and MERE_RUBY_GC_TIGHT=1. The genuine unchanged
-test-/integer extension is built separately for reference and candidate;
no gems are installed into the reference.

| File / selection | Main, both engines | Reference and candidate, both engines |
| --- | --- | --- |
| ruby/test_bignum.rb /test_digits/ | 5 tests, 21 assertions, 1 failure | 5 tests, 23 assertions, 0 failures |
| ruby/test_integer.rb /test_digits/ | 5 tests, 20 assertions, 0 failures | 5 tests, 20 assertions, 0 failures |

Max RSS from /usr/bin/time -l, in bytes, for these fixed-seed tight-GC runs:

| File | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: |
| test_bignum | 180158464 | 179503104 | 178208768 | 178274304 |
| test_integer | 166772736 | 168067072 | 168296448 | 169803776 |

sh run_corpus.sh --both and MERE_RUBY_VM=1 sh run_corpus.sh --both each
pass 897/897 programs with hash indexing ON and OFF. Both commands pass
all source gates and full record_hygiene. The generated-C bracket-depth
gate and an explicit record_hygiene check of this note also pass.
No full unit or Rails component suite was run and no workflow is changed.

A positive-base control exposed a separate existing difference:
0.digits(2**1024) is [] on both main and this candidate, versus [0] on
Ruby. That zero-output case is recorded for a separate cause-specific fix;
it is not counted as passing acceptance here. Nonzero positive-base
controls remain in corpus 1114. No upstream assertion or test is edited.
