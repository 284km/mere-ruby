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

`gc_body_tick` also says yes as soon as 16 MB of String bytes have been made since the pressure was last asked. It reads `str_pg_add`, which asking for the pressure sets back to 0 (`str_bytes`, through `gc_store_bytes`). The count of 32 is kept for everything else.

### Why 16 MB

The threshold decides only when the pressure is asked. Whether a collection then runs is the pressure test's: the stores must pass the base by the headroom. The headroom is twice what lived, at least 8 MB and at most what lived plus 32 MB.

A small threshold asks as soon as the headroom is passed. A loop that makes nothing but garbage then collects as often as the headroom's floor allows. A large one lets the bytes run past the headroom before anyone asks.

Collections, instructions retired (billions) and peak memory footprint (MB) for each threshold, one run each. "50%" and "100%" are a threshold of that share of the bytes that lived after the last collection, at least 8 MB.

| program | engine | main | 8 MB | 16 MB | 32 MB | 64 MB | 50% | 100% |
|---|---|---|---|---|---|---|---|---|
| `200.times { "a".b * 6_000_000 }` | evaluator | 32, 2.523, 124 | 51, 2.683, 131 | 34, 2.481, 118 | 34, 2.487, 118 | 32, 2.447, 124 | 51, 2.663, 131 | 35, 2.496, 130 |
| | VM | 13, 2.393, 541 | 50, 2.659, 176 | 34, 2.493, 204 | 33, 2.457, 221 | 17, 2.408, 427 | 49, 2.583, 182 | 34, 2.506, 210 |
| the program above | evaluator | 7, 1.163, 116 | 7, 1.154, 104 | 6, 1.165, 127 | 7, 1.162, 116 | 7, 1.161, 116 | 7, 1.153, 104 | 6, 1.146, 116 |
| | VM | 3, 1.106, 203 | 6, 1.142, 173 | 5, 1.131, 202 | 4, 1.112, 209 | 3, 1.104, 203 | 6, 1.133, 179 | 4, 1.113, 209 |

A threshold in proportion to what lived does not help here. These loops keep almost nothing, so 50% of it is below the 8 MB floor, and it behaves as 8 MB does. Where much lives, the headroom grows with it anyway.

At 8 MB the 6 MB loop collected every second turn, 50 times where main collected 13, for 13% more instructions on the VM. At 64 MB the VM's peak is back to 427 MB. At 16 MB:

- the loop collects 34 times on either engine;
- the VM's peak is 204 MB for main's 541;
- the program above ends with 12 MB on the VM and 30 MB on the evaluator (main: 132 and 24).

32 MB costs a little less, but leaves 30 MB on the VM there and peaks at 221 MB.

## Numbers

### The program above

After the `GC.start`:

| | evaluator | VM |
|---|---|---|
| main | 24 MB | 132 MB |
| this branch | 30 MB | 12 MB |

### Loops that keep making big Strings

Collections, instructions retired (billions) and peak memory footprint. The 6 MB loop was run three times, and the collections and the peak were the same each time:

| program | engine | main | this branch |
|---|---|---|---|
| `200.times { "a".b * 6_000_000 }` | evaluator | 32, 2.507, 124 MB | 34, 2.524, 118 MB |
| | VM | 13, 2.377 to 2.419, 541 MB | 34, 2.506 to 2.515, 204 MB |

The VM collects 21 more times and runs 4 to 5% more instructions: collections that main did not run, because nothing asked. The evaluator runs 0.7% more.

### What the tick costs elsewhere

Instructions retired, in billions, the median of three runs taken alternately. Both sides are built with the same Mere.

| program | evaluator: main | branch | VM: main | branch |
|---|---|---|---|---|
| `loop_plain` | 2.326 | 2.339 | 1.666 | 1.668 |
| a `while` of three statements, 1M turns | 10.584 | 10.589 | 6.168 | 6.196 |
| `300_000.times { "x#{i}" + "y" }` | 9.869 | 9.872 | 15.542 | 15.558 |
| a method call, 1M times | 24.173 | 24.256 | 25.657 | 25.692 |
| the program above | 1.206 | 1.204 | 1.146 | 1.171 |

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
