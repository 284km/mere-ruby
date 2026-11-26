# A builtin's own calls see no refinement

A refinement is lexical: it answers the calls written in the file (and after the `using`) that activated it. ruby's builtins are C, and the calls a C body makes (`rb_funcall`, `rb_check_funcall`) see no refinement at all. Here a builtin is interpreter code that runs with the caller's refinements still installed, so the calls it made itself were answered by them.

## What leaked

Found by running the same programs under ruby and under both engines, about 240 cases. Every one below answered with the refinement on both engines, and ruby answers with the class's own method:

- arithmetic inside a builtin: `sum` (with and without a block, on an Array or an Enumerator), `inject(:+)` and `reduce(:+)` (which raised a TypeError), `1 + obj`'s `coerce`;
- comparison: `sort`, `sort!`, `max`, `min`, `minmax`, `max(n)`, and the order of `(a..b).to_a` (`succ`);
- equality and hashing: `include?`, `index`, `delete`, `count(x)`, `Array#==`, `!=`, `-`, `&`, `|`, `difference`, `union`, `intersect?`, `uniq` (with and without a block), `tally`, `group_by`, `to_h { }`, `Hash#[]`, `Hash#[]=`, `Hash#==`, `find_index`;
- writing: `format`, `sprintf` and `String#%` with `%s`, and `join` of an object;
- implicit conversions: `flatten`, `Array()`, `String()`, `Integer()`, `String#+`, `Array#+`, `concat`, `zip`, `product`, `Hash#merge`/`update`, `File.join`, an index or a count given as an object (`to_int`), and the syntax's `[*obj]`, `f(*obj)`, `f(**obj)`, `|a, b|` and `for a, b in`.

`max`, `min`, `sort` and friends on Integers did not leak (the builtin compares them natively); the same methods on objects did.

## The change

- `refined_impl_for` answers no refinement for a call asked about while a builtin is registered at the depth now (`bi_reg`, which the dispatcher already kept for backtraces), unless the call is the one that entered the builtin (`bi_own_call`). A Ruby method or block the builtin runs is deeper, and installs its own refinements as it always did.
- A call a builtin makes through `invoke_val_c2` registers itself in turn, so `invoke_val_c2` runs it with the refinements suspended when it is not the registered call.
- The protocol calls inside the builtins that do not go through a registered builtin (the Hash key protocol, Array/Hash/Range equality, format, the splats, `conv_try_result` -- ruby's `rb_check_funcall`) call through `invoke_own`, which suspends the refinements around the one call. `sum` with a block adds through `apply_bin_own`.
- `send`, `__send__`, `public_send`, `method`, `public_method`, `instance_method`, `respond_to?`, and `call` on a Method keep the caller's refinements, as ruby's do. So do `&obj` (`to_proc`, ruby 2.6) and string interpolation (ruby 2.5), which were not touched.

Without a refinement, every new check stops at `map_len ref_active == 0`.

## Corpus 836

The leaks above, and beside them what must stay refined: the calls the file writes, blocks run by the builtins (`map`, `inject`, `each_with_object`), `&:sym`, `send`, `public_send`, `method(...).call`, `&obj`, interpolation, `respond_to?`, and a refined `alias_method` of a builtin called directly and as a Method. It matches ruby on both engines. main differs in 72 lines.

## Numbers

Instructions: the median of three runs alternating main (5521354d) and this branch on it. Both are built with Mere 9dec2ff6 (CI's). The objects are of a class with its own `<=>`, `==`, `eql?`, `hash`, `to_s`, `to_a` and `to_str`. "Under `using`" runs the same program after a `using` of a refinement of Array that none of them calls.

| program | evaluator: main | here | VM: main | here | under `using`, evaluator: main | here | VM: main | here |
|---|---|---|---|---|---|---|---|---|
| `sum` of 100 Integers, 20,000 times | 1.427 G | 1.426 G | 1.436 G | 1.442 G | 1.423 G | 1.438 G | 1.442 G | 1.444 G |
| `sum` with a block, 5,000 times | 4.842 G | 4.846 G | 5.138 G | 5.140 G | 4.833 G | 4.844 G | 5.136 G | 5.136 G |
| `inject(:+)`, 5,000 times | 8.032 G | 8.028 G | 8.036 G | 8.035 G | 8.023 G | 8.029 G | 8.029 G | 8.027 G |
| `sort` of 50 objects with `<=>`, 1,000 times | 23.130 G | 23.159 G | 29.621 G | 29.612 G | 23.155 G | 23.179 G | 29.581 G | 29.594 G |
| `max` of 50 objects, 5,000 times | 8.952 G | 8.944 G | 11.266 G | 11.280 G | 8.933 G | 8.931 G | 11.266 G | 11.267 G |
| `h[obj]` with an object key, 50,000 times | 7.899 G | 7.919 G | 8.741 G | 8.725 G | 7.896 G | 7.896 G | 8.723 G | 8.731 G |
| `uniq` of 50 objects, 2,000 times | 40.358 G | 40.397 G | 45.299 G | 45.322 G | 40.342 G | 40.365 G | 45.314 G | 45.322 G |
| `group_by` of 50 objects, 2,000 times | 2.576 G | 2.582 G | 2.723 G | 2.722 G | 2.584 G | 2.582 G | 2.712 G | 2.718 G |
| `Array#==` of 50 objects, 5,000 times | 13.768 G | 13.792 G | 15.611 G | 15.595 G | 13.766 G | 13.771 G | 15.577 G | 15.571 G |
| `include?(obj)` in 50 objects, 5,000 times | 13.652 G | 13.641 G | 15.347 G | 15.372 G | 13.635 G | 13.659 G | 15.369 G | 15.344 G |
| `format("%s-%d", obj, 1)`, 50,000 times | 3.908 G | 3.905 G | 4.554 G | 4.561 G | 3.907 G | 3.907 G | 4.547 G | 4.548 G |
| `join` of 20 objects, 5,000 times | 4.683 G | 4.674 G | 5.969 G | 5.970 G | 4.669 G | 4.678 G | 5.971 G | 5.966 G |
| `[*obj]`, 50,000 times | 2.996 G | 2.998 G | 3.105 G | 3.098 G | 2.994 G | 2.996 G | 3.090 G | 3.088 G |
| `"a" + obj` (`to_str`), 50,000 times | 3.300 G | 3.303 G | 4.201 G | 4.199 G | 3.294 G | 3.295 G | 4.202 G | 4.194 G |
| `each` with a block over 100, 3,000 times | 3.224 G | 3.230 G | 3.403 G | 3.404 G | 3.220 G | 3.219 G | 3.398 G | 3.396 G |
| a method call, 300,000 times | 11.468 G | 11.472 G | 11.641 G | 11.658 G | 11.462 G | 11.471 G | 11.635 G | 11.635 G |
| a self call, 300,000 times | 7.857 G | 7.867 G | 7.869 G | 7.898 G | | | | |
| app_fib | 201.137 G | 201.036 G | 191.959 G | 191.981 G | | | | |
| so_object | 149.683 G | 149.745 G | 161.750 G | 161.627 G | | | | |

Rails 8.1's warm boot (`bin/rails runner`), three runs each: the evaluator 49.1-49.4 G on main and 49.1-49.2 G here; the VM 48.4-48.5 G on both.

Every row but one is within 0.4% either way. The one, `sum` under `using` on the evaluator (+1.0%), measured again twice: -1.0% and +0.35%. It is noise.

Without a refinement, the only new work is `map_len ref_active == 0` in `invoke_val_c2` and `invoke_own`. The first version made `invoke_val_c2` a function of its own around the old one, and that frame cost 0.1% of a loop of calls and 0.3% of `uniq`; the check now heads `invoke_val_c2` itself.

## Checked

On 175a9a5b:

- `run_corpus.sh`: 992/992.
- `vm_corpus.sh`: all 992 programs on the VM, 0 fallback, 0 FAIL.
- vm_check: 246/246.
- The collector's root check.
- `test/ruby/test_refinement.rb` on both engines: 122 tests, 367 assertions, 0 failures, 0 errors, 1 skip. main gives the same.
- The probes this was found with, about 280 cases against ruby: no difference on either engine.

CHECKED
