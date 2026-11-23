# test_ast's time, round five: a lexical constant read is remembered, and the singleton-segment scan jumps

**The point.** test-unit's `assert` reads `String` and `Proc` (`when String, Proc`) on every call, and each read went through `lex_const_key`. That function rebuilt `"<scope>::<name>"` for every scope out to the top and hashed each one. At each scope it also asked `const_owner_scope`, whose `sng_seg_at` made a five-byte substring at every byte of the scope's name.

**The change.**

- `lex_const_key` remembers its answers in `lck_memo`, keyed by `"<cref>\x01<name>"`. They depend only on what `consts` holds, so `const_tbl_put` and `consts_del` — the only two places that write it — forget them all.
- `sng_seg_at` jumps from one `"(sng:"` to the next with `str_index_from`. The `)` at the end is tested once, instead of at every byte.

**Measured** (Mere 0c083af0 C output, main 94aa899b).

| | main | this branch |
|---|---|---|
| 100,000 `assert_equal(1, 1)` under test-unit | 40.09e9 instructions | 38.68e9 (−3.5%) |
| test_ast `test_all_tokens` on test_keyword.rb and test_proc.rb | 92.84e9 | 92.70e9 (−0.15%) |
| test_ast subset (78 tests) | 292.43e9 | 292.29e9 |

The small benchmark overstated it: test_ast's own asserts spend little of their time here. A trace showed that the memo is not being emptied during the tests: `consts` is written only at startup.

**What test_ast's time is, measured in the test itself.** The strings hashed per assert in test_keyword's all_tokens (an instrumented `__lang_hash_str`) come to about 1,320:

- 31.6% the frame's own keys (`self`, `__eid`, `__meth`, `__defcls`, …);
- 25.4% `Class#method` keys;
- 24.5% bare names: locals (`msg`, `prev`, `token_0`) and builtin method names (`[]`, `last`).

Locals live in the frame's string-keyed table too, so that one representation is over 40% of the hashing. Making locals and the frame's own facts slots is what the VM does. `MERE_RUBY_VM=1` runs the same number of instructions on this test, so test-unit's methods are not yet in its reach. Where test_ast's 450 seconds come from next is being decided with work2026-fd and the VM session.

**Checked.** `singleton_class` constant scopes (`class << self; X = 1`, nested modules, a singleton of a singleton, an object's singleton, and a read after `remove_const`) match ruby and main.

## Review of #185: a Box switch, other writers, and a bound

**A Ruby::Box switch left the memo stale.** `bx_switch` moves a box's constants out of and into `consts` directly (`bx_out` / `bx_in`), past `const_tbl_put` and `consts_del`. A remembered key could therefore name a constant the live box did not have. The caller's `map_get` then raised a bare StandardError where ruby raises NameError, and `defined?` said "constant". `bx_switch` now forgets the memo. The two other direct writers forget it too: Module#dup/clone's `copy_kv consts`, and the GC class sweep. No stale read was found through those, but the rule "every writer forgets" now holds as written.

**A bound.** Entries went only when a constant was written, so a program that makes classes without end grew the memo without end. 160,000 anonymous classes each reading four constants peaked at 375 MB, against 303 MB on main. The memo now lives in an arena of its own, given back whole (`map_recycle`) when it is forgotten big. It is forgotten at every class sweep and whenever it holds 8,192 answers.

| `Class.new` + `class_eval` reading 4 constants | main | first version | now |
|---|---|---|---|
| 80,000 classes | 238 MB | 278 MB | 237 MB |
| 160,000 classes | 303 MB | 375 MB | 313 MB |

**Witness.** corpus 853 runs the review's three box shapes in a `RUBY_BOX=1` child, as corpus 647 does:

- a read inside a box, then outside, then inside;
- a method defined in main, read again after a box defined the constant;
- two boxes.

It also covers reads around a constant's definition and `remove_const`, and a singleton class's constant through `dup`. The first version stops at the second box line.
