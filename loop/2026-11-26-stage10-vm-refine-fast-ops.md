# The VM's operator fast paths ask about this operator's refinement, not any refinement

The VM answers a number's arithmetic and comparison, `==` of a builtin, and a String's `<<` itself, without a method call. Three functions decide when it may:

- `vm_num_bin_ok` for arithmetic and comparison of numbers;
- `vm_bin_eq_ok` for `==` and `!=`;
- `vm_str_append` for String's `<<`.

Each refused whenever any refinement was active (`map_len ref_active > 0`). Under a `using`, then, every `i += 1` and `i < n` went down the general send, even when the refinement was of a class that has nothing to do with numbers.

The evaluator asks a narrower question. EBin calls `refined_impl_for world recv op`: is this operator refined for this receiver's class or one of its ancestors? It answers the operator itself when the answer is none.

## The change

The three functions now ask the evaluator's question:

- `vm_num_bin_ok`: `map_len ref_active == 0 || refined_impl_for world recv op == ""`.
- `vm_bin_eq_ok`: the same. For `!=` it also asks about `==`, in case a refined `==` should answer `!=`.
- `vm_str_append`: refuses only when String's `<<` is refined.

## Corpus 835

Corpus 835 covers these cases:

- A refinement of another class (Array) is active. Arithmetic, comparisons, `==` of builtins and String's `<<` answer as the builtins do.
- `Integer#+` and `String#<<` are refined after a `using`. Then:
  - the refined operators answer;
  - Float's `+`, Integer's `-` and Array's `<<` do not change;
  - a method and a proc written before the `using` are not refined;
  - a file that did not use the refinements (written to a temporary directory and required) is not refined;
  - a proc written after the `using` is refined;
  - `send` and `public_send` reach the refined operator.
- `Integer#==` is refined. `!=` and a method written before the `using` do not see it. Neither do the builtin comparisons inside `include?`, `index`, `Hash#key?`, `Array#==`, `sort` and `case`.

It matches ruby on both engines, with and without `MERE_RUBY_ATTR_IC_CHECK=1`.

Two gaps turned up while writing it. Both are on main too, on both engines, so they are left out of 835 and kept for a PR of their own:

- `1.method(:+).call(2)` under a refinement of `Integer#+` answers the builtin's 3. ruby answers the refined method.
- `[1, 2, 3].sum` and `inject(:+)` under the same refinement reach it from inside the builtin. ruby answers 6.

## Numbers

Instructions: the median of three runs alternating main (6d8a416d) and this branch on it (measured before the rebase onto 3e84227e). Both are built with Mere 9dec2ff6 (CI's).

| program | evaluator: main | here | VM: main | here |
|---|---|---|---|---|
| `i += 1` 300,000 times in a method | 2.308 G | 2.307 G | 1.641 G | 1.638 G |
| the same, under `using` of a refinement of another class | 3.920 G | 3.921 G | 6.817 G | 4.085 G |
| `s << "a" if s == "" \|\| i > 0` 100,000 times, under the same `using` | 12.58 G | 12.61 G | 14.73 G | 12.29 G |
| a self call, 300,000 times | 7.808 G | 7.806 G | 7.822 G | 7.822 G |
| app_fib | 200.7 G | 200.8 G | 191.9 G | 191.9 G |
| so_object | 149.7 G | 149.6 G | 161.4 G | 161.3 G |
| Rails 8.1's warm boot (`bin/rails runner`) | 49.2 G | 49.1 G | 48.4 G | 48.2 G |
| the leak loop (`test_complemented_method_entry_memory_leak`'s body, 60,000 times) | 12.64 G | 12.65 G | 17.10 G | 17.11 G |

Under the `using`, the VM's loop went from 22,700 to 13,600 instructions per turn. The evaluator's is 13,100.

The leak loop's gap between the engines does not move. Its `using` is in a class body whose methods do no arithmetic, so its cause is elsewhere. That is the next thing to look at.

## Checked

- `run_corpus.sh`: 987/987 (rebased on 3e84227e; 985/985 on 6d8a416d).
- `vm_corpus.sh`: all 987 programs on the VM, 0 fallback, 0 FAIL.
- vm_check: 246/246.
- The collector's root check.
- `test/ruby/test_refinement.rb` on both engines: 122 tests, 367 assertions, 0 failures, 0 errors, 1 skip. main gives the same.

CHECKED
