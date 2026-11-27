# Rails-2: squeeze the instance variables' slab

Branch `rails-ar-slab-compact`, first on main `b9ca06d6`, main `491cc5ca`
merged in on 2026-11-28. The PR is opened on the macOS numbers; it is merged
only after the Linux comparison below is added. The fixture probe's
intermittent regression is not explained (see "Open").

## What the change does

`iv_slab_squeeze` (m_state.mere) runs in `gc_collect` after mark and sweep,
only when the collection is not `nc` (not on the stack it serves). When the
slab holds more than `2 * live + 65536` slots, it copies every live area to a
scratch Vec, recycles the slab, pushes the areas back and rewrites each
record's base (`iv_mk_rec nb cap shape`, so the size class and shape stay the
same). The free lists are reset. `MERE_RUBY_SLAB_SQUEEZE=1` squeezes at every
collection that leaves a free slot (a check mode for the corpus).
`MERE_RUBY_GC_LOG` prints each squeeze and its collection's time;
`MERE_RUBY_STORE_STATS` has a row `iv_slab_squeezes`. Corpus 1075.

## Checked

1. Areas keep their size class and shape: `cap = 2^class` is re-encoded
   through `iv_cap_class`, so `iv_grow`'s `n1 <= cap0` and the VM's
   `sh_len s1 <= iv_rec_cap r` hold after a move.
2. No collection between reading a base and writing through it: the door
   functions in m_state take no callbacks and run before the evaluator;
   `iv_copy` and `ivar_names_of` read the base and then only call m_state;
   `gc_mark_area` runs inside the collection, before the squeeze; the VM's
   read and write read the base at the use, and a write that misses re-reads
   `iv_rec` after `assign_one`.
3. Corpus, six modes on this branch:
   - plain 0 FAIL; vm 1 FAIL (503_tcp_connect_deadlines, timing; passes in
     sq-vm); sq 0; sq-vm 0 (the last two with SHAPES_CHECK, 1014/1014).
   - sq-stress (`SLAB_SQUEEZE=1 GC_STRESS=50`): 1012/1014. 676_tail_calls
     does not finish under `GC_STRESS=50` even without the squeeze (300 s);
     526_objectspace_internal_class differs under `GC_STRESS=50` on main too.
   - sq-stress-vm: every file up to 497 passed (0 FAIL). The run stopped
     in the reference ruby on 498 (its FIFO between two threads) after
     2 h 24 min, while another corpus run was stuck on the same file; it
     was stopped and is to be run again on its own from the start.
   - Fiber / Thread / Enumerator / Ractor files (128) under
     `SLAB_SQUEEZE=1 GC_STRESS=50`, evaluator and VM: 0 new differences.
4. Fixture probe (`zz_fixture_probe_test.rb`, normal GC): 1 squeeze in 61
   collections, 6,969,476 -> 787,139 slots in 36 ms, inside a 483 ms
   collection (neighbours 290-461 ms).
5. Make-and-drop loops: 0 squeezes on evaluator and VM; a loop that keeps
   1/10 squeezed once and not again over 30 rounds. Instructions -0.07% and
   -0.13%.

## Open: an intermittent regression in the probe

Under `MERE_RUBY_GC_TIGHT=1`, two runs each, alternating:

| build | squeezes | preload | footprint after preload | peak |
| --- | --- | --- | --- | --- |
| without the squeeze | 0 | 94 s, 88 s | 1,427 MB, 1,251 MB | 1.69 GB, 1.57 GB |
| with the squeeze | 1, 1 | 465 s, 334 s | 2,785 MB, 2,297 MB | 3.10 GB, 2.67 GB |
| with the squeeze, `GC_LOG` | 3 | 94.6 s | 1,307 MB | 1.51 GB |

In the bad runs RSS is like the baseline's and only the footprint is larger,
and every store `STORE_STATS` counts is the same or smaller. The suspicion:
`vec_recycle` on a pinned arena retires it, and a suspended stack keeps the
retired arena. Not confirmed.

To confirm, a diagnostic binary prints three things under
`MERE_RUBY_GC_LOG`; it is the generated `mr.c` with three lines added and is
not committed:

- in `mere_vec_Val_recycle`, after `pinned` is computed, for a Vec longer
  than 100,000: `len`, `owned`, `pinned`, the arena's bytes and
  `__lang_retired_n`;
- in `__lang_region_retire`, when an arena over 50 MB is kept: its bytes
  and the number of stacks that pin it;
- in `__lang_region_collect_retired`, when such an arena is finally freed.

On a small top-level script the slab's recycle took the unpinned path
(8.8M slots, 607 MB arena), and two retired arenas (97 MB, 240 MB) were kept
and later freed.

### Two runs with the diagnostic and `GC_LOG` (2026-11-27 evening)

Both were good runs: preload 133 s and 87 s, footprint after preload
1,248 MB and 1,303 MB, peak 1.63 GB and 1.68 GB, two squeezes each.

- In both, the first squeeze's `vec_recycle` of the slab took the pinned
  path: a 350 MB arena was retired and kept, pinned by 4 stacks. The
  second squeeze kept a 53 MB arena the same way.
- Both arenas were freed in a later collection. Every arena over 50 MB that
  was kept during the run was freed again before the end.

So the pinned retire happens on every run, good or bad; what is not seen
yet is an arena that stays. All three runs with `GC_LOG` were good and both
runs without it were bad, so printing may change the timing.

A second diagnostic (`MERE_RUBY_DIAG=1`) records the same three events in
memory with the time since start and prints them at exit, together with
every arena still retired at exit.

### Three more runs without `GC_LOG` (2026-11-28 early morning)

The diagnostic binaries are the bad build's `mr.c` with only the diagnostic
lines (and, for the last run, the limit below) added.

| run | squeezes | preload | footprint after preload | peak | still retired at exit |
| --- | --- | --- | --- | --- | --- |
| `DIAG=1` | 2 | 77 s | 1,230 MB | 1.55 GB | 60 MB, none over 50 MB |
| `DIAG=1` | 2 | 89 s | 1,262 MB | 1.54 GB | 39 MB, none over 50 MB |
| `DIAG=1 SLAB_SQUEEZE_MAX=1` | 1 | 80 s | 1,270 MB | 1.52 GB | 198 MB, one of 135 MB |

- Every run was good. The first squeeze's arena (339-353 MB) was retired,
  kept, and freed 11-17 s later each time, so a kept arena does not explain
  the bad runs.
- Both bad runs made one squeeze and good runs two or three, but a run held
  to one squeeze (`MERE_RUBY_SLAB_SQUEEZE_MAX=1`, a diagnostic knob, ends
  with 4.85M slots like the bad runs' 4.74M) is good too. The number of
  squeezes is not the cause either.
- So far: 7 runs of the squeeze build, 2 bad. Both bad runs were the
  original binary on the afternoon of 2026-11-27; the original binary with
  `GC_LOG` and all five diagnostic runs were good. What is left: the
  machine's state that afternoon, or something only in the original binary.

### The original binary and the baseline again, with vmmap (2026-11-28)

`vmmap --summary` after `fixtures+gc` and after `preload`, only `GC_TIGHT`
and `STORE_STATS` set.

| build | squeezes | preload | footprint after preload | peak |
| --- | --- | --- | --- | --- |
| squeeze (original) | 2 | 183 s | 1,896 MB | 2.20 GB |
| squeeze (original) | 1 | 101 s | 1,265 MB | 1.60 GB |
| squeeze (original), vmmap | 2 | 126 s | 1,387 MB | 1.64 GB |
| squeeze (original), vmmap | 2 | 85 s | 1,227 MB | 1.53 GB |
| without the squeeze, vmmap | 0 | 89 s | 1,231 MB | 1.47 GB |
| without the squeeze, vmmap | 0 | 80 s | 1,255 MB | 1.85 GB |

The first of these had 47 GB of disk free, so a full disk is not the whole
story. After preload, most of the footprint is `VM_ALLOCATE` (the arenas):
508-758 MB resident and 366-564 MB compressed, on both builds; all the
`MALLOC_*` rows together stay near 120 MB.

All runs so far: the original squeeze binary 7 (bad 2, middling 1, a little
heavy 1, good 3), the diagnostic binaries 5 (all good), the build without
the squeeze 4 (all good in preload and footprint after preload; the peak
moves between 1.47 and 1.85 GB). The bad runs came while the machine was
loaded; the cause is not found.

## eager_test under run.py (2026-11-28, macOS)

`run.py run --jobs 1 --side mere` on `eager_test.rb` (family RSS limit
2 GiB, 600 s), the two builds alternating. The compressor's pages are from
`vm_stat` before and after each run (16 KiB pages).

| build | state | cases | time | peak family RSS | compressor pages |
| --- | --- | --- | --- | --- | --- |
| squeeze | COMPLETE | 198/199 | 435 s | 1.29 GiB | 867,500 -> 913,523 |
| without | COMPLETE | 198/199 | 405 s | 1.44 GiB | 913,501 -> 829,104 |
| squeeze | COMPLETE | 198/199 | 398 s | 1.11 GiB | 829,070 -> 977,191 |
| without | COMPLETE | 198/199 | 386 s | 1.71 GiB | 977,119 -> 881,381 |

- Neither build hits `MEMORY_LIMIT` on this machine any more. The case that
  fails on both is `test_exceptions_have_suggestions_for_fix` (the runs had
  no `--framework-bootstrap`, so no did_you_mean).
- With the squeeze the peak RSS is lower in both pairs (1.20 against
  1.58 GiB on average). macOS RSS goes down when the compressor takes pages,
  and the compressor held 13-15 GiB through these runs, so the size of the
  gain is not settled here.

## Next

1. The same comparison on Linux (docker), where CI's limit applies and
   nothing is compressed: the two builds alternating, two runs each, with
   run.py's limits. The PR is merged only after this is in it.
2. sq-stress-vm with `CORPUS_KEEP_GOING=1` on the merged tree (the run
   without it stopped at 526, which differs under `GC_STRESS=50` on main
   too).
3. If the retired-arena suspicion holds, propose a fix before writing it
   (for example: when the slab's arena is pinned, skip the squeeze and try
   at the next collection).
