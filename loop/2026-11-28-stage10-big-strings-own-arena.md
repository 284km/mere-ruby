# A big String is kept in an arena of its own

After #393 took the StrBufs out of the default region, what the msgpack loop still kept was the String page in use. This is the loop with the C extension taken out:

    r = Random.new(12345)
    50.times { f = []; r.rand(4).times { f << r.bytes(r.rand(1024*1400)) }; io = StringIO.new(f.join); f.each { |s| io.read(s.size) }; GC.start }

## What kept it

Strings live in pages of 4,096. A collection gives back a page none of whose Strings lived. A page that has live Strings it compacts, which gives back the bytes of the Strings that died in it. But Mere refuses a compaction while a suspended stack points into the arena. The collector runs on a coroutine, and the program's stack, stopped below it, points into the page in use. Mere compacts under a pin only once the arena has doubled since the first refusal (v0.1.651).

So the page in use kept every big String that died in it until its arena had doubled. A probe that is not in this change counted the loop's collections: 42 of 51 compactions were refused. The page grew to 44 to 54 MB before one went through, and came back to 23 MB, where 6.5 MB lived.

## The change

A String of `str_big_min` bytes (256 KB) or more is kept in a Vec of its own, with an arena of its own. The page's slot holds "".

- `sraw` looks in `str_big` when the slot is "" and some big String exists. `sput`, `mkstr` and `mkstr_join` put a big String there and a small one in the page. A big String made small again leaves `str_big`.
- When a big String dies or is replaced, its Vec waits for the next sweep, and the sweep recycles it (`vec_recycle`) and pools it. Nothing points into that Vec then, whatever points into the page.
  - It is not recycled at once, because the old text may be in flight in the very call that replaces it: `sput id (sraw id ++ tail)`.
  - It is not recycled at a sweep that runs on the program's stack (`nc`), as a compaction is not.
- `vec_recycle` gives back the arena's growth and keeps one 256-byte block. It moves to a fresh arena where a suspended stack points into a block, and retires the old one.
- `str_bytes` counts the big Strings' bytes, so the pressure sees them.

### Why 256 KB

| threshold | `loop_rss` cases of 32 KB Strings, VM, from the tree | a loop of 20 KB Strings: instructions |
|---|---|---|
| 256 KB | 1.11 to 1.86 (three over 1.6) | no change |
| 16 KB | 1.08 to 1.29 | +3.3% on the evaluator, +3.5% on the VM |

A String of 20 KB or so is a common size: a JSON document, a template's result. So the threshold is 256 KB. The 32 KB cases' VM ratios are the page in use, and they are bounded: 2,000 to 16,000 turns gave 1.39, 1.86, 1.58 and 1.19.

### And Mere's own change

0e's Mere branch, `arena-return-dead-pages`, gives back a refused arena's pages that no live value and no pin can reach (madvise). It touches no mere-ruby source. It gives back RSS, but not macOS's footprint, and only for an arena that has handed out 8 MB or more. This change frees a big String's arena outright, at any size. The two do not conflict.

## Numbers

### The program above

Peak memory footprint on macOS. All builds are of main 856e61ba with the same Mere. "#393" is the StrBuf change, and "both" is #393 with this change.

| turns | engine | main | #393 | this change | both |
|---|---|---|---|---|---|
| 50 | evaluator | 266 MB | 218 MB | 236 MB | 137 MB |
| 50 | VM | 293 MB | 210 MB | 242 MB | 142 MB |
| 200 | evaluator | 641 MB | 327 MB | 620 MB | 189 MB |
| 200 | VM | 712 MB | 304 MB | 642 MB | 205 MB |

`str_store` after the last `GC.start`, 200 turns: 54 and 71 MB on main, 24 and 30 MB with both. ruby's footprint for 200 turns is 48 MB.

### Instructions

Instructions retired, in billions. Each figure is the median of three runs taken alternately, and both sides are built with the same Mere.

| program | evaluator: main | this change | VM: main | this change |
|---|---|---|---|---|
| small Strings: `+`, `==`, a Hash read, interpolation, `upcase`, `<<`, 300,000 times | 33.396 | 33.525 | 28.467 | 28.573 |
| small Strings, 15 operations, 100,000 times | 39.737 | 39.849 | 36.213 | 36.349 |
| `loop_plain` | 23.381 | 23.383 | 12.644 | 12.645 |
| `200.times { "a".b * 6_000_000 }` | 2.540 | 2.444 | 2.534 | 2.451 |
| the program above | 16.525 | 16.393 | 16.552 | 16.384 |

The look into `str_big` costs 0.3 to 0.4% on small Strings. Big Strings cost 0.8 to 3.8% less. Probably because they are no longer copied when a page is compacted, but that was not measured apart.

### tools/loop_rss_check.rb

Two new cases, from the tree:

| case | engine | main | this change | both |
|---|---|---|---|---|
| big Strings: `s + "b"`, `<<`, `sub!` of 300 KB, 2,000 times | evaluator | 4.06 (FAIL) | 4.24 (FAIL) | 1.01 |
| | VM | 5.15 (FAIL) | 4.23 (FAIL) | 1.03 |
| a big String replaced, 2,000 times | evaluator | 1.35 | 1.00 | 1.00 |
| | VM | 1.39 | 1.03 | 1.04 |

The first needs #393 too: `sub!`'s StrBuf was the default region's.

## Corpus 1150

Corpus 1150 does with Strings of 300 KB what a program does with any String, and prints what each one holds. It covers `<<`, `[]=`, `replace` with a short String and back, `slice!`, `dup`, `freeze`, `force_encoding`, `sub!` and `gsub!`, five kept across 50 dead ones and a `GC.start`, an aliased one appended to, `clear` and growing again, `join`, and `ObjectSpace.each_object`. It matches ruby on both engines, and under GC stress on both. main matches too: it checks that behaviour is unchanged.

## What is left

- The page in use still keeps Strings under 256 KB that died in it, until its arena doubles. 0e's Mere change gives back their pages' RSS where the arena is past 8 MB.
- The collector's survivor list (`gc_str_surv`) leaves its old copies in the default region as it grows: a high-water mark, as #393's record says.

## Checked

On 6ab7818d, which is main e47a4bb3 (with #393) and this change:

- `run_corpus.sh` 1034/1034, corpus 1150 included. `strbuf_region_check.py` read a fresh `mr.c`.
- `vm_corpus.sh`: all 1034 on the VM, 0 fallback, 0 FAIL.
- vm_check 246/246.
- The collector's root check.
- `tools/loop_rss_check.sh` 28/28: "big Strings" at 1.01 and "a big String replaced" at 1.00.
- `tools/class_watermark_check.sh`.
- Corpus 1150 under GC stress on both engines.
