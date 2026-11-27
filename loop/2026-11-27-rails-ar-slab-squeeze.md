# Rails-2: squeeze the instance variables' slab (work in progress)

Branch `rails-ar-slab-compact`, base main `b9ca06d6`. No PR yet: the fixture
probe shows an intermittent regression that has to be explained first.

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

## Next

1. Two probe runs with `GC_TIGHT=1 DIAG=1` and no `GC_LOG`. Look only at the
   diagnostic lines (pin, retire, free, what is still retired at exit),
   since the times move with the machine's load.
2. sq-stress-vm again, on its own.
3. If the retired-arena suspicion holds, propose a fix before writing it
   (for example: when the slab's arena is pinned, skip the squeeze and try
   at the next collection).
