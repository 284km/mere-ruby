# C API: big buffers are mapped and unmapped, not left in malloc's cache

msgpack 1.8.7's own suite peaked at 3.66 GB on the evaluator and 2.97 GB on the VM; ruby 4.0.10 peaks at 0.93 GB. This finds where that memory was and returns the C API's part of it to the system.

## Where the memory was

Measured as aidocs' memory-attribution describes: the spec file first, then the example, then the allocator.

- **By spec file (evaluator, peak RSS).**
  - packer_spec: 2.7 GB (ruby 664 MB).
  - cruby/buffer_io_spec: 1.6 GB (ruby 169 MB).
  - cruby/buffer_spec: 1.1 GB (ruby 235 MB).
  - The other eleven files: 180 to 360 MB.
- **The example.** In packer_spec, "doesn't crash when using recursive packers concurrently" alone peaks at 2.36 GB (ruby 661 MB). It writes a 6 MB String from a recursive packer 22 times, with a `GC.start` in each callback. Outside rspec, the same steps ended at 1.76 GB (ruby 648 MB).
- **By stage, outside rspec** (growth from the start; mere-ruby on the evaluator):

  | stage | ruby | mere-ruby |
  |---|---|---|
  | 22 Strings of 6 MB made | +126 MB | +121 MB |
  | the same written to a Packer | +126 MB | +352 MB |
  | `to_s` of 132 MB | +126 MB | +308 MB |

  Strings that C never touches cost what they cost in ruby.
- **What `vmmap` and `heap` said at the end** (1.55 GB after a `GC.start`):
  - Freed large blocks that macOS's malloc keeps for reuse (`MALLOC_LARGE (empty)`): 990 MB. That was most of it. Starting the process with `MallocLargeCache=0` (a launch setting, for the measurement only) ended it at 867 MB.
  - Live malloc: 315 MB.
  - Mere's regions: 227 MB.
- **Who made the large blocks** (`MallocStackLoggingNoCompact`, `malloc_history -allEvents`, then `heap`):
  - **`rb_str_new(NULL, n)`'s zero bytes** (string.c `make`): calloc'ed, copied into transit and freed. That was 23 blocks, 881 MB in all, from msgpack's `msgpack_buffer_all_as_string`.
  - **A String's bytes in its mirror** (mirror.c `string_room`): one buffer for every big String C touches, freed when the mirror goes.
  - **The transit buffer** (core.c `bytes_out`): it grows to the biggest String that went through it and never shrinks. After the 132 MB `to_s` it held 134 MB for the rest of the run.

## What changed

- **core.c: big buffers.**
  - `mr_big_alloc`, `mr_big_free` and `mr_big_realloc` map a buffer of 1 MiB or more and unmap it when it is let go. A smaller one is malloc's, as before.
  - The bound is 1 MiB because below it malloc reuses the block. From there up, every such buffer gets a copy of its bytes, which costs more than the map and the unmap.
  - glibc maps blocks this big already, and Mere sets its threshold to 64 KiB.
- **mirror.c: a String's own buffer.**
  - The buffer goes through `own_alloc`, `own_resize` and `own_free`.
  - `own_mapped` says whether it was mapped. A buffer C made with malloc and the mirror took over is freed as malloc's, whatever its size.
- **core.c: transit.**
  - A big transit buffer goes back to the size of the transfer at hand after 64 transfers in a row that used a quarter of it or less.
  - It does not shrink at once, because work that passes big Strings over and over would then map at every one.
  - A transit set aside around a write-back (`mr_transit_save`) is a big buffer too.
- **string.c.** `rb_str_new(NULL, n)` puts its zero bytes straight into transit (`mr_put_zero_bytes`).

## Checked

On c913da27 + this change, with Mere 9dec2ff6 and reference ruby 4.0.10. The baseline is the same commit without the change. RSS figures are single runs, three each.

| | before | after |
|---|---|---|
| packer example outside rspec, evaluator: RSS at the end | 1,625 / 1,796 / 1,928 MB | 868 / 868 / 1,000 MB |
| the same, evaluator: peak | 2,708 MB (all three) | 2,043 MB (all three) |
| the same, VM: RSS at the end | 2,694 / 2,824 / 2,921 MB | 1,867 / 1,971 / 2,394 MB |
| the same, VM: peak | 3,898 / 3,941 / 4,196 MB | 3,574 / 3,595 / 4,324 MB |
| msgpack's whole suite, evaluator: peak | 2,216 / 2,653 / 2,727 MB | 1,497 / 1,827 / 2,142 MB |
| msgpack's whole suite, VM: peak | 2,191 / 2,563 / 2,732 MB | 1,795 / 2,222 / 2,463 MB |

- **The VM keeps more Strings than the evaluator, apart from the C API.** After `22.times { s = "a".b * 6_000_000; s.bytesize }; GC.start`, the String store is 132 MB on the VM and 24 MB on the evaluator. That is why the VM's numbers stay high. It is handed to the VM's work separately.
- **Linux** (docker, Debian, ruby:4.0.10 with clang 19, aarch64). The packer example on the evaluator, three runs each:
  - before: RSS at the end 965 / 1,623 / 1,623 MB, peak 1.89 / 2.24 / 2.38 GB;
  - after: RSS at the end 965 / 1,554 / 1,555 MB, peak 1.89 / 2.27 / 2.27 GB.
  - No difference. glibc already maps and unmaps blocks this big, so this change is macOS's. Both builds reach about 2 GiB on this example, so it stays close to CI's bound there.
- **Big transfers over and over** (instructions of the loop alone, with the start-up subtracted; median of three, alternating):

  | loop | instructions | time | peak |
  |---|---|---|---|
  | to_s, 512 KiB x 2000 (under the bound) | -0.6% | 3.14 -> 3.33 s | same |
  | to_s, 1 MiB x 1000 | +1.7% | 5.65 -> 5.04 s | 360 -> 339 MiB |
  | to_s, 2 MiB x 500 | +1.8% | 5.20 -> 4.94 s | 454 -> 433 MiB |
  | to_s, 8 MiB x 120 | +2.8% | 5.53 -> 5.57 s | 748 -> 642 MiB |
  | Unpacker#feed, 2 MiB x 500 | +6.2% | 2.50 -> 2.52 s | 440 -> 432 MiB |
  | 1 in 16 writes of 2 MiB, x 2000 | +2.2% | 1.79 -> 1.74 s | same |

  The added instructions are the map, the unmap and the first touch of fresh pages, where malloc handed back pages it had kept.
- **capi_check.**
  - Evaluator and `--vm`: 419 contracts on both sides, the same under collection stress. Each negative control fails.
  - New contracts at the end of api.rb, for big Strings that C makes, fills, cuts down and grows (from a mapped buffer to malloc's and back), and many made and dropped with collections between them.
  - They are at the end because earlier in the file they grew the heap enough that join_in_c's long call made no collection on the VM.
  - A build that frees a mapped buffer with `free` aborts in these contracts.
- **The C API corpus programs under `MERE_RUBY_GC_STRESS=1`.** These are the eleven that use a native extension: 509, 527, 722, 763, 914, 918, 919, 1018, 1019, 1020 and 1025. They print what ruby prints on the evaluator and on the VM.
- `run_corpus.sh --both`: the gates, then 1027/1027 with the hash index on and off. `MERE_RUBY_VM=1 run_corpus.sh --both`: 1027/1027.
- capi_spec_check: 2420 of 2602, the recorded count. capi_mkmf_check passes. capi_gem_check: seventeen gems give the same output on both sides. headers_check: 194 headers, 10 patched, 22 vendored sources unchanged.

## Left

- **B: shared bytes for big Strings.** `rb_str_dup` / `rb_str_new_frozen` of a big String copy its bytes into a second mirror, where ruby shares them. In the packer example that is 22 x 6 MB that C keeps alive through the Packer.
- **C: the peak.** After this change the peak is still about 2 GB against ruby's 0.68 GB. Attributing it needs a snapshot at the peak itself.
- **Time.** The suite still takes about 15 times ruby's time.
