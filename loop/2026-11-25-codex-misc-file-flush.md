# Write buffered file bytes at their recorded offset

A3. Branch base: main `ab5a9bfd`. Reference: clean Ruby 4.0.10, revision
`a704b7cd95`. Build: Mere `9dec2ff6`, mgz `661a01d8`, O2. No reference
gems were installed.

Corpus 1115 covers seek/write, holes, r+ write/read, truncate, independent
objects, sync=true and external replacement between flushes. Both engines
match Ruby. The existing cached descriptor path now writes only the buffered
bytes at wpos instead of reading and rewriting the file. The write loop
advances wpos and retains the unwritten suffix when a syscall fails.

## Related upstream comparisons

Unchanged Ruby 4.0.10 files run one at a time through unittest/try.sh.
Every invocation uses `--seed=1` and `MERE_RUBY_GC_TIGHT=1`. Reference,
main and candidate pass the selections below on both engines. RSS is the
maximum resident set size in bytes from `/usr/bin/time -l`.

| Selection | Result | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | --- | ---: | ---: | ---: | ---: |
| ruby/test_file.rb | 4 tests, 132 assertions, 0 failures, 0 errors, 0 skips | 164593664 | 163184640 | 165150720 | 176029696 |
| ruby/test_io.rb | 7 tests, 100 assertions, 0 failures, 0 errors, 0 skips | 178634752 | 194363392 | 230801408 | 230916096 |

The file selection is test_truncate (4 tests / 132 assertions); the IO
selection covers seek, ungetc/ungetbyte with seek, buffered multiargument
writes and syswrite (7 / 100). The file helper is the unchanged upstream
-test-/file native extension, built separately for the reference and the
Mere C API. No substitute implementation or fake test helper is used.

## Partial writes

`python3 unittest/file_flush_partial_check.py` interposes write for only
the fixture file. Five bytes are accepted, then ENOSPC is injected. After
the fault is disabled the second flush must consume only the remaining
suffix at the advanced offset. The reference and candidate match on both
engines for r+ and w+; main fails because it rewrites the complete image.

## Cost per flush

`bench/file_flush.rb 47185920 100 MODE --seed=1`, with
`MERE_RUBY_GC_TIGHT=1`, performs 100 flushes of 20 bytes. Fixture setup is
outside the timer; each reported cost is seconds per flush. All rows use
unchanged O2 binaries. Max RSS includes fixture setup and is in bytes.

| Mode | Main evaluator seconds | Candidate evaluator seconds | Main VM seconds | Candidate VM seconds |
| --- | ---: | ---: | ---: | ---: |
| r+ | 0.05378597021102905 | 0.0007727289199829101 | 0.07327540874481202 | 0.0005019998550415039 |
| w | 0.07535001039505004 | 0.0002706789970397949 | 0.08498221158981323 | 0.000813300609588623 |

| Mode | Main evaluator RSS | Candidate evaluator RSS | Main VM RSS | Candidate VM RSS |
| --- | ---: | ---: | ---: | ---: |
| r+ | 266321920 | 225673216 | 313065472 | 218791936 |
| w | 313327616 | 274317312 | 407322624 | 291028992 |

## Acceptance still running

The full `run_corpus.sh --both` and `MERE_RUBY_VM=1 run_corpus.sh --both`
sweeps are queued sequentially. Their source gates and full record_hygiene
results will be recorded after completion. The direct witnesses and upstream
selections above do not constitute a full-corpus result. No full unit suite
or Rails component suite was run, and no workflow is changed.
