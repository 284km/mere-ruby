# A for loop's lone splat target is compiled with no state

main's CI failed `tools/iseq/compare_files.rb` on corpus 830:

    DIFF 830_for_splat_targets.rb at [13, 90, 2, 4, :stack_max]: mine=6 ruby=5

It is not a recent change: 751362a3 fails the same way. It reproduces on macOS too.

## Why

`pm_compile_for_node_index` compiles a splat target (`for *t in ...`) with `pm_compile_target_node(..., NULL)`, no multiple-assignment state. With none, an index, call or constant path target is written straight to:

- its receiver and arguments are left where they were pushed;
- no `topn` copies them above the value, and no `swap` for a call;
- the cleanup pops nothing;
- a constant path swaps its parent under the value.

Both compilers -- `lib/iseq_compiler_ext.rb` and the native one in `ic/` -- passed a state there. So `for *h[:z] in o` copied `h` and `:z` with three `topn` and popped them after. It wrote the same values, but in a different sequence, with a stack_max of 6 where ruby's is 5.

`for *s.x in o` and `for *A::B in o` differed the same way. `compare_files.rb` names only the first difference of a file, so 830's second one (line 37) was not shown.

## The change

- `target` (Ruby) and `ic_target` (Mere) take the stateless form when they are given no state. The Ruby side uses `nil`; the Mere side uses `ic_mstate_no ()`, a state of `[-1]`.
- `for_index` / `ic_for_index` hand a splat target no state. Several targets keep theirs, as ruby's do.
- The embedded copy of the Ruby compiler (`m_pathname_lib.mere`) is regenerated.

## And the evaluator's for with several targets

While writing 837: `for a, h[:q] in [[1, 2]]` gave `a` the whole `[1, 2]` and `h[:q]` nil on the evaluator. It does so on main too. The VM gave 1 and 2, as ruby does.

ruby compiles several targets the same way as a splat: the values each gave, or the one value as an Array when it converts to one (`length`, `[]`, `Array.try_convert`). The evaluator's splat target already took them that way (`for_rest_args`), and its several complex targets now do too.

`for o.x, y in [[1, 2]]`, where ruby 4.0 calls `2.x = 1` and fails, is still not followed (the comment at `parse_for` says why). There `y` is now 2 where it was nil.

## Corpus 837

A lone splat target written straight to:

- an index, with one argument and with two, the key evaluated again on every turn;
- an attribute, and the same through `&.` on nil;
- a constant path, and one under `::`.

Beside them, several targets among which an index or an attribute: the values of a two-value yield, of a one-Array yield, of a bare yield, and of an object with `to_ary`. It matches ruby on both engines. Both compilers give ruby's sequence for it.

## Checked

On 3fbe3921:

- `tools/iseq/compare_files.rb` over corpus/*.rb: 994 the same (830 was the one DIFF).
- `tools/iseq/native/check.sh` over corpus/*.rb: 994 the same.
- `tools/iseq/compare_with_ruby.rb` with snippets.txt: 460 ok, 0 bad.
- The embedded copy is current (`tools/gen_pathname_lib.rb`).
- `run_corpus.sh`: 994/994.
- `vm_corpus.sh`: all 994 programs on the VM, 0 fallback, 0 FAIL.
- vm_check: 246/246.
- The collector's root check.

CHECKED
