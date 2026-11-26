# An object's variables: the rest of the way through the door (note 559, step 2a)

Step 1 (#295) put every reader and writer of one object's variable behind `iv_get` / `iv_set` and the rest.
What still read an object's key itself: the walks of the whole table, two keys handed from one function to another, and the thread-locals.
This moves them behind the door too, so that step 2b (shapes, and the values in one slab) changes what the door does and not who calls it. **Nothing about what is kept changes: the keys are the same Strings.**

## What moved

- **Whose a key is**, and where its name starts, is the door's: `iv_key_owner` (was the collector's `gc_owner_of`), `iv_key_name_at`, `iv_name_eq`, `iv_name`, `iv_del_at`, in m_state beside `iv_key`.
  - The collector's marking (`gc_fixpoint`) and sweep (`gc_collect`) ask it. The sweep deletes a dead object's variables with `iv_del_at`, and finds a File's descriptor by `iv_name_eq .. "__f_fd"` rather than the key's ending.
  - `flush_files_at_exit` (a File's unflushed `__f_buf`), `ivar_names_walk` (the listing's fallback) and `iv_copy` (dup, clone) ask it too. `iv_copy` no longer goes through `ivars_copy_pfx`, which is left to a Proc's and a Binding's keys.
- **A key handed around**: `exc_cause_link_to` answered the key of the exception whose cause links back, and its caller read and wrote under it. It answers the exception's id (-1 for none), and the caller uses `iv_get` / `iv_set .. "__cause"`.
- **The thread-locals**: `fb_tl_base` answered a Thread's or a Fiber's id as text, and every `Thread#[]`, `#[]=`, `#key?`, `#keys`, `#fetch`, `thread_variable_*` built `<id>@__tl_<key>` from it.
  It is `fb_tl_owner` now, the id as a number, and those go through `iv_*` (11 sites, the recursion guard of `inspect`, `Thread#fetch` and `tl_note_key`).

The other walks of the table (four in main.mere, and `ivars_copy_pfx`) are of other owners' keys: a String's, an Array's, a Hash's (`hng_key`), a class's (`cls:`), a Proc's and a Binding's. Step 2b leaves those where they are.

## What step 2b replaces, and what it keeps

- The collector still walks the table with `map_iter` and asks the door about each key. Step 2b marks an object's values where they are kept, when the object is marked, so this walk shrinks to the other owners' keys.
- The name index (`iv_idx`, `ivar_names_of`, `ivar_names_idx`) is still keyed `"<id>@"`; a shape holds the names in 2b.
- The Prism loader's new-object path (`iv_file_new`, `iv_put_new`) is still a door of its own.

## A callback per variable is too dear

The first version had the door walk the table and call back with the owner, the name and the value (`iv_each_split`, a curried closure of four arguments).
On 30 collections of 100,000 objects with four variables each, that took **33% more instructions**. Cutting the name out as a String per variable was not the cause: without it, 43%.
Each call of a curried closure through a parameter makes its partial applications. So the walks call `map_iter` themselves, and ask the door only about a key. That costs what the old code did: the same work, a named function instead of a line.

## Checked

Instructions retired, the median of 3 runs taken in turn, `MERE_RUBY_GC_TIGHT=1`. Both binaries are built with the Mere CI uses (9dec2ff6); the base is main (#295, 75549121).

| loop | evaluator | VM |
|---|---|---|
| 30 `GC.start` over 100,000 objects of 4 variables | -0.3% | -0.2% |
| 300 `dup` and `clone` among 20,000 objects | +0.6% | +0.6% |
| `s += @x`, 300,000 times | -0.0% | -0.2% |
| `@x = i` | -0.1% | +0.2% |
| `s += a.x` (attr_accessor) | +0.1% | +0.1% |
| control (no instance variable) | +0.0% | -0.3% |

The copy still walks the whole table, as before; step 2b makes it the object's own variables.

- `./run_corpus.sh --both`: 955/955, plain and with `MERE_RUBY_VM=1`.
- Gates: dead_defs, dup_defs, gc_roots, meth_writes, name_len, ns_names, bracket_depth, loop_rss.
