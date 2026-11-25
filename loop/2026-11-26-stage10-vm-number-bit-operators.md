# A number's bit operators on the VM

The VM's speed, from the benchmarks furthest from the evaluator (note 558; #300 took so_spectralnorm's `for` loop). so_meteor_contest was 1,208 G instructions on the VM and 1,134 G on the evaluator.

## Where

Its search tests and joins boards, Bignums: `board & cmask == imask`, `board | mask`.

On the VM a send of two numbers and an operator is answered in `vm_call` without a scope when `vm_num_bin_ok` says the evaluator's EBin arm would reach `eval_bin_prim` with nothing before it taking the call: no TracePoint, refinement, undef or alias of the operator, no operator of the program's own.

It named `+ - * / < <= > >=` only. Two Integers in a Fixnum's range take `int_fast_op` before it, so it was a Bignum's `&` that went past: through `vm_scoped` (a scope from the pool, a fail handler, a region) and the parser's `EBin` made in it.

For a number on the left, the EBin arm's way to `eval_bin_prim` is the same for `% & | ^ << >> **` as for the operators named: the arms before it that look at the operator are for Strings, Arrays, Ranges and objects.

## The change

`vm_num_bin_ok` takes `% & | ^ << >> **` too. Nothing else changes: the same checks, the same call (`eval_bin_prim` under the operator's name, `bi_reg_set`).

## Numbers

Instructions on the VM, the median of three runs alternating main and this branch:

| program | main | here | the evaluator |
|---|---|---|---|
| `x = (b & c == 2)`, a Bignum b, 200,000 turns | 9.00 G | 8.11 G | 8.65 G |
| `x = b \| c`, the same | 9.65 G | 8.73 G | 9.31 G |
| so_meteor_contest | 1,208.0 G | 1,142.0 G | 1,134.1 G |
| so_nsieve_bits | 475.2 G | 475.2 G | 450.9 G |
| so_pidigits | 388.5 G | 388.7 G | 382.3 G |

so_nsieve_bits' operators are on Integers in a Fixnum's range, which `int_fast_op` answered already, and so_pidigits' Bignum arithmetic is `+ - * /`.

## Witnesses

Corpus 828: each of the seven operators over Integers, Bignums, a negative Bignum, a Rational and 0, with what each refuses; Floats' `%` and `**`; a board and its masks; `b & nil`, `b % 0`, `b << "x"`; a program's own `Integer#&`, and a refinement of `Integer#|`, which the operator reaches.

## Recorded

`2.5 ^ 3`, `2.5 << 3` and `2.5 >> 3` raise StandardError "mere-ruby: ^ type error" on both executions, as on main; ruby's is NoMethodError, "undefined method '^' for an instance of Float".

CHECKED
