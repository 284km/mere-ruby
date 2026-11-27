# A loop of big Strings is collected in the middle on the VM too

After a loop of big Strings, the VM kept far more String bytes than the evaluator:

    22.times { s = "a".b * 6_000_000; s.bytesize }; GC.start

After the `GC.start`, `str_store` was 132 MB on the VM and 24 MB on the evaluator.

## What kept the bytes

The Strings were not live. Leaving out each of the collector's routes to the running stack (`MERE_RUBY_GC_DBG` 1, 2 and 4) changed nothing. What happened instead:

- **No collection ran during the loop on the VM.** The GC log shows none between start-up and the `GC.start`, where the evaluator ran six.
- **The final collection gives back no String pages.** Strings live in pages of 4,096. A page goes back only when nothing in it is live, and the current page stays open. A small program has all its Strings in the current page, so a collection at its end keeps the dead Strings' bytes too, on either engine. Five turns keep 30 MB on both.

The evaluator's 24 MB is what its last collection in the middle of the loop left. The VM had none.

### Why the VM met no collection

A safepoint (`gc_point`) asks for the pressure only one time in 32 (`gc_body_tick`). The evaluator reaches a safepoint at every block run and between statements. The VM reaches one:

- at a line's start, but not at a frame's first statement;
- one time in 64 at a jump back.

So a loop of 22 turns reached too few safepoints for one of them to ask. Each turn made 6 MB, and 132 MB went by without the pressure being asked. A loop on one line, `while i < 22; ...; end`, asks one time in 64 × 32.

## The change

`gc_body_tick` also says yes as soon as 8 MB of String bytes have been made since the pressure was last asked. It reads `str_pg_add`, which asking for the pressure sets back to 0 (`str_bytes`, through `gc_store_bytes`). The count of 32 is kept for everything else.

### Why 8 MB

The pressure test collects once the stores pass the base by the headroom. The headroom is twice what lived, at least 8 MB and at most what lived plus 32 MB. Asking every 8 MB of new String bytes puts a collection at most one floor's worth of headroom after the point where it was due, whatever the count of safepoints.

## Numbers

### The program above

After the `GC.start`:

| | evaluator | VM |
|---|---|---|
| main | 24 MB | 132 MB |
| this branch | 18 MB | 18 MB |

### Loops that keep making big Strings

Collections, instructions retired (billions) and peak memory footprint, one run each:

| program | engine | main | this branch |
|---|---|---|---|
| `200.times { "a".b * 6_000_000 }` | evaluator | 32, 2.517, 124 MB | 51, 2.688, 131 MB |
| | VM | 13, 2.338, 541 MB | 50, 2.634, 176 MB |
| `4000.times { "a" * 300_000 }` | evaluator | 63, 2.299, 81 MB | 63, 2.292, 81 MB |
| | VM | 62, 2.335, 135 MB | 62, 2.334, 135 MB |
| 300 Strings of 1 MB, 100 kept at a time | evaluator | 5, 1.496, 340 MB | 5, 1.503, 340 MB |
| | VM | 5, 1.519, 428 MB | 5, 1.502, 414 MB |
| 200 Strings of 1 MB, all kept | evaluator | 4, 1.323, 309 MB | 4, 1.324, 309 MB |
| | VM | 4, 1.372, 449 MB | 4, 1.354, 428 MB |

Only the 6 MB loop collects more often. It now collects about when the headroom says to: 1.2 GB made, with a live set of a few MB and a headroom of 8 MB to about 24 MB, comes to about 50 collections. Before, the evaluator collected late, and the VM later still, reaching 541 MB. The 50 collections cost 7% more instructions on the evaluator and 13% more on the VM.

### What the tick costs elsewhere

Instructions retired, in billions, the median of three runs taken alternately. Both sides are built with the same Mere.

| program | evaluator: main | branch | VM: main | branch |
|---|---|---|---|---|
| `loop_plain` | 2.334 | 2.346 | 1.669 | 1.673 |
| a `while` of three statements, 1M turns | 10.600 | 10.598 | 6.162 | 6.195 |
| `300_000.times { "x#{i}" + "y" }` | 9.863 | 9.893 | 15.566 | 15.569 |
| a method call, 1M times | 24.215 | 24.264 | 25.673 | 25.704 |
| the program above | 1.204 | 1.195 | 1.150 | 1.184 |

## What is left: the VM's peak

On the program above the peak is still 182 MB on the VM and 109 MB on the evaluator; on the 6 MB loop, 176 MB and 131 MB. What is known so far:

- The first collection in the middle of the loop leaves 24 MB in `str_store` on the VM, where the evaluator's leaves 6 MB. Each later one leaves 6 MB on both.
- Leaving out the collector's routes to the running stack (`MERE_RUBY_GC_DBG` 1, 2 and 4) does not change those 24 MB. So the bytes are not live Strings: the page they are in was not compacted at that collection.
- Mere refuses a compaction while a suspended stack pins the arena (v0.1.651). It compacts under a pin only once the arena has doubled since the first refusal. The VM's first collection is probably refused by such a pin, and a later one goes ahead. This has not been confirmed: nothing in Mere reports a refusal.

The base after that first collection is higher, so the next one comes later. That accounts for part of the difference in peak. This branch does not change it.

## A check that did not work

A `tools/loop_rss_check.rb` case, a big String each turn, did not give a steady answer. The ratio of RSS after to RSS before took two values on the same binary: 1.34 and 1.61 on the VM, 0.86 and 1.60 on the evaluator. The RSS before depends on where the warm-up's collection falls. So the check is corpus 841 instead.

## Corpus 841

Corpus 841 makes a 6 MB String in each of 22 turns and asks whether `GC.count` grew during the loop. It does this for five loops:

- `times`;
- `while` over lines;
- a String kept in a local;
- a String made in a method;
- `while` on one line.

ruby answers true to all five. On main, the VM answers false to the last two. This branch answers true to all five on both engines.

## Checked

CHECKED
