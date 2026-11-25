# One door to an object's instance variables

The first step of note 559 (aidocs): an object weighs about 1 KB with four instance variables here, against ruby's 93 bytes, and most of it is how the variables are kept.
Every object's variables are in one Map, keyed `"<object id>@<name>"`, and each key is a String of its own.
Before that can change, every reader and writer of an object's variable has to go through one place. This change makes that place and moves the readers and writers to it. **What is kept, and how, is unchanged: the keys are the same Strings.**

## The door

In m_state, beside `iv_put`:

- `iv_key oid name`: the key, `"<oid>@<name>"`.
- `iv_get`, `iv_has`, `iv_set`, `iv_del tbl oid name`: an object's variable by its id and its name without the "@". `iv_set` writes through `iv_put`, so the name index (`iv_idx`) is kept as before.

In m_eval_leaf, beside `ivar_self_key`:

- `ivs_get`, `ivs_has`, `ivs_set tbl self name`: self's variable, whatever self is. An object's goes through `iv_*`; a class's, a String's, an Array's, a Hash's, a Proc's, a Binding's and main's keep their keys (`"cls:..@"`, `"str:..@"` and the like).
- `ivs_owner self`: whether self can hold a variable at all.
- `iv_copy world src dst`: every variable of one object to another (dup, clone, `Exception#exception(msg)`).

## What goes through it

- About 900 sites in main.mere, m_eval_leaf.mere, m_driver.mere and m_state.mere: 741 calls of `iv_*` in main.mere, 153 in m_eval_leaf.mere, 11 in m_driver.mere and 5 in m_state.mere, and 14 of `ivs_*`.
  - Most were mechanical: `map_get T (str_of_int X ++ "@N")` became `iv_get T X "N"`, and the same for `map_has`, `map_delete` and `iv_put`.
  - Where the key was first bound (`let k = str_of_int id in ... (k ++ "@N")`), the site was changed only when nothing between rebinds `k` or `id`, and within one function.
    Every such site was checked again with a stricter rule (a tuple or pattern binding of either name), and none matched.
  - The rest by hand: the File helpers `file_univ_code` and `file_unget_len` take the id, the thread bodies' `k`, `file_flush_obj`, the Struct slots, `instance_variable_get`, `instance_variables`, the exception's cause chain, `ofrozen_set`.
- The VM: `vm_ivar_get` (getinstancevariable) and the `@x = v` assignment (setinstancevariable runs the evaluator's) go through `ivs_has` / `ivs_get` / `ivs_set`, as df asked (note 559 §6).
- The four copies of "every variable of this object to that one" are now one, `iv_copy`.

## What does not yet

These still spell an object's key, and the next step (shapes, note 559 §3 案 1) has to move them:

- **The walks of the whole table**: 9 `map_iter` over it (main.mere 7, m_eval_leaf.mere 2): the collector's, Marshal's, `ivars_copy_pfx` under `iv_copy`, the name index's check (`ivar_names_walk`).
- **The name index** (`iv_idx`, `ivar_names_of`, `ivar_names_idx`): keyed by `"<oid>@"`. It is the door's own listing, and moves with it.
- **Keys handed around**: `exc_cause_link_to` answers a key that its caller reads and writes (`deep9`), and `tl_note_key` takes a thread-local base that is not always an object's id.
- **The Prism node loader** (m_prism_load.mere): a new object's variables are filed whole with `iv_file_new` and written with `iv_put_new`. It is a door of its own already, for a new object.
- **The C API** (capi/object.c, capi/needed.c) reaches the variables through the evaluator's functions, which go through the door now. Its mirror of RBasic is unchanged.

## A Mere bug found on the way

A variable that a **pattern** binds, captured by a **closure**, is emitted in C as the prelude's function of the same name when there is one (`id`, `incr`, ...). The type check passes, and the interpreter runs it right; the C does not compile (`use of undeclared identifier 'mu_id_as_value'`).

```
type V = VObj of int | VNone;
let use = fn (k: int) -> fn (s: str) -> k + str_len s;
let f = fn (v: V) ->
  match v with
  | VObj id -> (let g = fn (n: int) -> use id "x" + n in g 1)
  | VNone -> 0;
print (str_of_int (f (VObj 41)))
```

`mere` prints 43; `mere -c` and clang refuse it. Named `x9` or `oid`, it compiles; a parameter named `id` captured the same way compiles too.
Here the source already avoided it in one place (`let fid9 = id in`), and three more closures needed the same `let` (`go9` of Enumerator::Chain#rewind, the Struct-aware copy's `cp9`, `instance_variables`' `ivs9`). To be reported to Mere.

## Checked

- Builds; the C compile is what finds the bug above, so a wrong capture cannot pass silently.
- Every fourth corpus program on both engines (476 runs) and the ivar-related ones (140 runs): all match ruby.
- An ivar-heavy loop (200,000 objects, three variables, `instance_variable_get`): 3.55 s / 113 MB before, 3.54 s / 113 MB after; with the VM 3.40 s → 3.32 s, 104 MB both.
- `./run_corpus.sh --both`: 953/953, plain and with `MERE_RUBY_VM=1`.
- Gates: dead_defs, dup_defs, gc_roots, meth_writes, name_len, ns_names, bracket_depth, loop_rss.
