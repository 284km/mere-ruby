# An append writes only what is new

**Why.** Rails-2 round 3 (activerecord, sqlite3) had migration_test at 501 s and 1,756 MB. A sample of it showed the main thread under `file_flush_obj`, in `open`, `read` and `write`.

**The cause.** A File opened with "a" flushed by reading the whole file, adding its buffer and writing the whole file back:

```
write_file path ((if file_exists path then read_file path else "") ++ buf)
```

So one flush cost the size of the file, and between the truncate and the write the file on disk was empty. A logger flushes per line. ActiveRecord's tests log every SQL statement to `debug.log`, which stays in the tree and grows through a round: 45 MB at the end of round 3. Late in the round, each logged statement read 45 MB and wrote 45 MB.

**The change.** `file_flush_obj` opens the path for appending (`fd_open path "a"`), writes the buffer through that descriptor and closes it. A write the kernel takes part of leaves the rest in the buffer. A path that cannot be opened goes to the File's own descriptor, as before.

**Measured** (this machine, other jobs running at the same time).

One flush of a 20-byte line, File with `sync = true`, 100 flushes:

| file size | main 655eec3e | this change | ruby 4.0.10 |
|---|---|---|---|
| 45 MB | 64.5 ms | 0.25 ms | 0.003 ms |
| empty | 0.36 ms | 0.23 ms | 0.004 ms |

migration_test alone, starting from the same 45 MB `debug.log`:

| | time | max RSS | result |
|---|---|---|---|
| round 3 build (main 30de57d4 + #225) | stopped by hand at 283 s, 7 of 67 tests done (26 s to 52 s a test, rising) | 620 MB at that point | - |
| this change | 177 s, all 67 tests | 1,444 MB | 67 runs, 37 errors |

In round 3 itself, with the log smaller at that point of the round, the same file took 501 s and 1,756 MB.

**What this does not fix.** The 37 errors of migration_test are not from the flush. The migrator removes a migration's class with `Object.send(:remove_const, name)` and loads its file again. Here a class defined again under a removed name still has the old class's methods, so the test's own `ValidPeopleHaveLastNames#change` (`drop_table :people`) runs. That is a separate change. The time of a test in that file still rises (10 s to 25 s) for a reason not yet found.

**What it means for a round's numbers.** Time and max RSS of the files late in a round were raised by the size the log had reached. Rounds before this change cannot be compared with rounds after it on those two columns.

**Corpus 979** pins what a program can see: two File objects appending to one path keep each other's bytes, bytes written from outside the handle stay, the size only grows flush by flush, a seek does not move an append, a NUL and a 0xFF byte, a buffered handle flushed by `close`, a file created by the append, "a+", and a Logger. It matches ruby 4.0.10 with and without `MERE_RUBY_VM=1`. It also matches on main: the old flush gave the same content, so the corpus program is not a witness of the cost. The cost is in the table above.

**Left.**

- **"w" and "r+" flush the same way**: they read the file, splice the buffer in at the write position and write the whole file back. A log opened with "w" and `sync = true` has the same cost per flush. Not changed here.
- Per flush this is still about 80 times ruby (0.25 ms against 0.003 ms): a descriptor is opened and closed for every flush.

**Checked.**

- `run_corpus.sh --both`: 875/875. `MERE_RUBY_VM=1 run_corpus.sh --both`: 875/875.
- The source gates: dead_defs, dup_defs, gc_roots, meth_writes, name_len, ns_names, bracket_depth. `tools/loop_rss_check.sh`. `mspec/record_hygiene.sh`.
