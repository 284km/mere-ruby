# Parser follow-up 6: Array element source lines

The evaluator now preserves the actual source lines of binary, unary,
interpolated String and !call elements in multiline Array literals.
Existing method, index and bare calls retain their correct lines. VM
backtraces remain correct. Corpus 992 contains 36 output rows covering
all shapes, actual files, nested expressions, continuations and heredocs.

Main 03694405 is integrated by merge 3c553557, including parser changes
#247, #263 and #277. Review corrections share the parser's observed-line
epoch across adjacent elements and emit a line annotation only when a
call-capable element changes line. Literal elements do not advance that
cache. A continued logical line uses its actual physical token position.
Only line numbers and epochs are cached; token tails are not retained.
No element rescans the remaining token tail. General ln_before behavior
outside this Array-specific path is unchanged.

## Final measurements and related original CRuby tests

After merging main 03694405, corpus 992 matches all 36 rows, stderr and
status on evaluator and VM against clean Ruby 4.0.10. The ordinary O2
candidate SHA-256 is cde6d7d1c1aef9b58ecdb0476a17a6a3f3fe19a22c7707465d24046a95bf2f7c.
The matching main SHA-256 is 94473bd3a46d13124327720c4251a39f3604b584bafc4ef9c90ca670fe61a67c.

Three alternating main/candidate pairs, fixed --seed=1, GC_TIGHT=1:
| Shape / engine | Main seconds | Candidate seconds | Main max RSS bytes | Candidate max RSS bytes | Median instructions delta |
| --- | ---: | ---: | ---: | ---: | ---: |
| array / evaluator | 0.050077 | 0.048989 | 142196736 | 142229504 | +0.300% |
| array / VM | 0.049353 | 0.048235 | 143048704 | 143163392 | +0.432% |
| hash / evaluator | 0.086950 | 0.090938 | 183631872 | 183697408 | -0.028% |
| hash / VM | 0.087281 | 0.086178 | 202489856 | 202620928 | +0.094% |
| operators / evaluator | 0.105362 | 0.103986 | 224198656 | 224313344 | +0.544% |
| operators / VM | 0.102401 | 0.104664 | 225017856 | 225148928 | +0.507% |

Array/Hash sizes remain 100,000 elements / 50,000 keys. Operator arrays
contain 100,000 computed elements. The old ~14 MB annotation allocation
and ~4.5% instruction increase are removed; the remaining instruction
change is approximately 0.3–0.5% for Arrays and -0.03–0.09% for Hashes.

test_backtrace unchanged original selections, --seed=1, GC_TIGHT=1:

| Phase | Result | Max RSS bytes |
| --- | --- | ---: |
| ref-eval | 3 tests, 8 assertions, 0 failures, 0 errors, 0 skips | 22855680 |
| main-eval | 3 tests, 8 assertions, 0 failures, 0 errors, 0 skips | 169852928 |
| candidate-eval | 3 tests, 8 assertions, 0 failures, 0 errors, 0 skips | 172146688 |
| main-vm | 3 tests, 8 assertions, 0 failures, 0 errors, 0 skips | 173572096 |
| candidate-vm | 3 tests, 8 assertions, 0 failures, 0 errors, 0 skips | 175472640 |

test_allocation unchanged original selections, --seed=1, GC_TIGHT=1:

| Phase | Result | Max RSS bytes |
| --- | --- | ---: |
| ref-eval | 2 tests, 8 assertions, 0 failures, 0 errors, 0 skips | 77348864 |
| main-eval | 2 tests, 8 assertions, 0 failures, 0 errors, 0 skips | 312819712 |
| candidate-eval | 2 tests, 8 assertions, 0 failures, 0 errors, 0 skips | 311705600 |
| main-vm | 2 tests, 8 assertions, 0 failures, 0 errors, 0 skips | 322650112 |
| candidate-vm | 2 tests, 8 assertions, 0 failures, 0 errors, 0 skips | 326483968 |



## Completed acceptance

- `sh run_corpus.sh --both`: **954/954 PASS**, hash index ON and OFF.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: **954/954 PASS**, hash index ON and OFF.
- Both sweeps used exactly the r4 binary and fixture tree measured above.
- All eight source gates PASS: gc_roots, dup_defs, dead_defs, meth_writes,
  name_spec, rx_caps, ns_names and name_len.
- Generated-C bracket gate PASS: 155 required, 1024 supplied.
- Full record_hygiene and explicit completed-loop record_hygiene PASS.
- `git diff --check` and staged whitespace checks PASS.
- Clean reference Ruby 4.0.10 selected with `tools/ref_ruby.sh`.

Measurements use fixed --seed=1 and MERE_RUBY_GC_TIGHT=1. The reference,
matching main, and both candidate engines run the unchanged related CRuby
selections one file at a time. No full unit or Rails component suite is
run; no workflow is changed. Ordinary O2, compiler 9dec2ff6, mgz 661a01d8.
The correction and this completed record are submitted in one push.
