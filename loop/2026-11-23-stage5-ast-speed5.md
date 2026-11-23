# test_ast's time, round four: an empty clear costs nothing, and newlines are found with memchr

**The point.** `eval("")` spent a quarter of its time clearing two tables that were already empty. A Mere `map_clear` writes -1 over the table's whole hash index, and the index is as large as the table ever grew. `lex_src` clears `tc_off` and `lvt_names` for every source it lexes. Once a large file has been lexed, every later lex pays for an index sized to that file, including the lex of an empty eval string. test_ast's `test_memory_leak` evals `""` a million times under a 10-second limit, and it took 7 to 9 seconds. On a loaded machine it timed out, on main's build as well (load average 141; and once at 3 parallel runs).

**The change.**

- `lvt_reset` and `lex_src` clear `lvt_names` and `tc_off` only when they hold something.
- Numbering a source's newline marks (`number_nls_at`) wrote `"<line>@"` into `tc_ln` for every mark: a key made, and hashed three times, per newline. That count now lives in `tc_lnc`, keyed by the line number itself.
- `tc_off` and the rest of `tc_ln`, which only a logical line that passes a newline writes, are not asked at all while they are empty, so the per-mark `str_of_int` is gone too.
- `nl_count_to` and `tc_nls` count newlines by jumping from one to the next with `str_index_from` (memchr). Before, they compared one character at a time.

**Measured** (Mere 0c083af0).

| | before | after |
|---|---|---|
| `1_000_000.times { eval("") }` | 77.3e9 instructions, 6.07 s user | 56.6e9 (−27%), 4.40 s |
| test_ast's `test_memory_leak` alone (limit 10 s), two runs each | 6.48 s, 7.06 s | 4.97 s, 5.12 s |
| test_ast subset (78 tests, `astbench`) | 294.6e9 | 291.6e9 (−1.0%) |
| test_ast whole file, `--seed=42`, mean of 3 to 4 runs | 3216e9 | 3197e9 (−0.6%) |

The whole-file difference is inside the noise.

- **Noise.** test/unit runs each test under a Timeout thread, so collections fall at different points from run to run even at a fixed seed. Instructions move by ±2%, and maxRSS moved between 845 and 1965 MB for the same build (998 to 1187 MB for main's).
- **test_memory_leak.** It passed in all four of this build's whole-file runs, and failed by timeout in one of main's three.

**What the rest of test_ast's time is.** test_ast spends most of its time in `test_all_tokens` (254 s of 440 locally), `test_ranges` (119 s) and `test_not_cared` (63 s). Outside the test harness, `test_all_tokens` on test_keyword.rb takes 1.7 s; inside it, 7.7 s. The difference is test-unit itself: `assert_equal(1, 1)` costs 45 µs here against 0.6 µs on ruby, and the test asserts one to three times per token (67,825 tokens in that file).

Counting the strings hashed (an instrumented `__lang_hash_str`) shows that one `assert_equal` hashes about 755 strings:

- about 270 are the keys of the frame's own table (`self` 45, `__eid` 27, `__meth` 27, `__defcls` 26, `__fid` 22, `__defidx` 18, `__has_blk` 17, `__captured` 16, ...);
- the rest are method-table keys such as `Test::Unit::Assertions#assert` and the ids written as digits.

That is the frame-as-a-string-keyed-map design, and it is the next thing to take apart. The clears in this round were the part that could be removed without touching it.

**Tried and dropped.**

- **An 8-entry key cache in Mere's String-keyed maps.** This widened #88's one remembered entry to eight, picked by the key's address. The test_ast subset went from 292.24e9 to 292.03e9 instructions (−0.07%). A frame's table is new for each call, and each key is read once or twice right after it is written, so the address cache does not hit. What would help is fewer keys, not cheaper ones.
- **Building `String#bytes` with a loop instead of a recursion.** test_all_tokens takes the bytes of every file twice, but the four heaviest of those tests ran the same 168.7e9 instructions either way.
