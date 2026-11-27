# A frame's head, read and written through doors

Note 560, B, step 1 of 3 (note 560 section 7). The head of a frame -- the entries a call writes for the frame itself -- is to move out of the frame's Map into an area of its own. This step changes no behaviour: it gives every read and write of those entries one place to go.

## The head

Twelve entries:

- `self`, `__fid`;
- `__meth`, `__callee`, `__defcls`, `__defidx`;
- `__cref`, `__nest`, `__cvcls`;
- `__args`, `__params`, `__has_blk`.

They were read and written as Map entries in 603 places outside comments:

- `lv_get` / `lv_has` / `lv_set` of a frame, which look along its chain;
- `map_get` / `map_has` / `map_set` of one frame.

`self` alone is 310 of them.

## The doors

One function for each key and use that the code makes: 46 of them, `fh_<key>_<use>` in `m_state.mere`. For example `fh_self_lv_get env`, `fh_cref_set frame v`, `fh_fid_has frame`. Each is the call it replaces, its key a literal.

A first version passed the key as a number (`fr_lv_get env fk_self`) and looked its name up in a table. That cost a call about 190 instructions (+0.7% on a self call, +1.0% on app_fib): a literal key's hash is ready, a name fetched at run time is hashed again. One function per key and use costs nothing: the numbers below.

## What step 3 has to change besides the doors

These still read the frame's Map as a whole:

- `gc_mark_env`, which marks every entry and gives `__cref`, `__defcls`, `__cvcls` and `__nest` to the class marking by key. In step 3 it walks the head's area when it meets `__fh`.
- The walkers that copy or list a frame's entries: a Binding's copy (`main.mere`, the `str_starts_with n9 "__" || str_eq n9 "self"` copy), `local_variables` (which leaves `__` names and `self` out), `frame_pool_put`'s wipe.
- `lv_owner env "__fid"` in two places, which asks which frame of a chain holds the id.
- The frame pool: a frame given back to the pool, and one the pool drops, gives back its head's area too (44's condition).

## Numbers

Instructions, the median of three runs alternating main (bb24014f) and this branch, both built with Mere 9dec2ff6 (CI's).

| program | evaluator: main | here | VM: main | here |
|---|---|---|---|---|
| a self call, 300,000 times | 7.794 G | 7.787 G | 7.804 G | 7.810 G |
| a method calling another object's method, 300,000 times | 9.429 G | 9.421 G | 9.047 G | 9.037 G |
| a top-level method, 300,000 times | 5.812 G | 5.810 G | 5.656 G | 5.654 G |
| app_fib | 204.4 G | 204.2 G | 195.9 G | 195.9 G |
| so_object | 150.3 G | 150.3 G | 162.2 G | 162.2 G |
| Rails 8.1's warm boot (`bin/rails runner`) | 49.3 G | 49.3 G | 48.6 G | 48.7 G |

## Checked

- `run_corpus.sh` 977/977; `vm_corpus.sh` 977 on the VM, 0 fallback, 0 FAIL.
- vm_check 246/246; the collector's root check.

CHECKED
