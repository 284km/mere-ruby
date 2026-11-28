# C API: what C appends to a big String goes to the interpreter as the tail

After #390, msgpack's whole suite still peaked at 2.65–2.89 GB on Linux. Two spec files besides packer_spec made most of it:

| spec file alone (Linux, MB) | mere-ruby | ruby |
|---|---|---|
| cruby/buffer_io_spec | 1,899 | 96 |
| packer_spec | 1,836 | 369 |
| cruby/buffer_spec | 1,714 | 138 |
| the other 11 | 112–266 | 24–26 |

Most of the buffer specs' memory is the interpreter's, not the C API's. Their largest example, buffer_io_spec's 'random read', does the same with `StringIO#read` in place of `MessagePack::Buffer`, with no C extension. It still ends at 200–250 MB on both engines, against ruby's 15 MB, with 6.5 MB of live Strings. That part is the String store's arenas, which keep the bodies of dead and replaced Strings. It is handed on separately. This change is the C API's own part.

## What the C API's part was

A ledger of malloc's blocks of 64 KiB or more, by caller with a call chain of seven frames (LD_PRELOAD, Linux), on 'random read' with `GC.start` in each round:

- The mirror's own buffers and transit: 160 MB allocated in all, none of it held at the end.
- `write_back → mr_up → mu_capi_up → mu_sput → __lang_region_alloc_aligned`: 832 MB allocated in all, 189 MB live at the peak, 154 MB still live after `GC.start`. The same rounds without the C extension: 357 MB in all.

msgpack's `Buffer#read(n)` from an IO starts from `rb_str_buf_new(0)`. It then appends 32 KiB at a time with `rb_str_cat`, calling `io.readpartial` between appends. `rb_str_cat` appends in the String's struct, which is then watched, so at every `readpartial` the whole String so far went back with `MR_STR_SET`.

Each write-back did three things:

- It copied the whole String into transit.
- It made a new body in the interpreter (`sset`).
- It dropped the String's cached answers: whether it is all ASCII, and whether it is valid UTF-8.

msgpack then reads `RSTRING_LEN` after the `readpartial`. C fetches the String again for that, and the fetch asked the interpreter for its ASCII-ness, which it had just forgotten. It rescanned the whole String every time: `mu_str_is_ascii` is most of main's samples in this loop.

## What changed

- **mirror.c.** A String's struct keeps the length it last synced with the interpreter (`synced`). At a write-back, MR_STR_CAT sends only the bytes past that length when:
  - that length is 64 KiB or more;
  - the String only grew;
  - its first `synced` bytes still hash as they did at the sync.

  Otherwise all of it goes, as MR_STR_SET, as before.
  - The hash now takes the length at its end (`hash_end`), not at its start, so one pass gives both the hash of what the String was and of what it is (`hash_two`). The first version hashed the synced part a second time, which made the same loop slower on Linux.
  - When `rb_mere_string` has just sent the tail of what C wrote through a pointer it kept, it fetches the String again, as below, instead of returning the struct as it is.
- **main.mere.** MR_STR_CAT appends the bytes where the String is (`sput (sget h ++ tail)`), when the String is the length C says; otherwise it refuses and C sends all of it.
  - It keeps the String's two cached answers the way String#<< does: the bytes appended decide them (`str_append_answers`, split out of `str_push` with no change to it).
  - The bytes count as String bytes made, as a new String's do (`str_pg_add`), so the collector's pressure is asked once 16 MB of them have been made.
  - An earlier version queued the tail with `str_push`. But C fetches the String again after each call into Ruby, which folded the queue in at every crossing anyway (610 of 640 crossings in this loop). On macOS that version peaked 120–230 MiB above main in this loop.

The interpreter still makes the whole body again at every crossing, as main does, because C fetches the String after every call into Ruby. Not fetching a String the interpreter has not changed would need a per-String change count kept by every write to a String, a hot path. That is not part of this change.

### Why the interpreter does not check that Ruby left the String alone

A write Ruby made since the sync is already in the struct's first `synced` bytes:

- C reaches the bytes through `rb_mere_string`, which fetches the String again after any call into Ruby.
- `RSTRING`, `RSTRING_PTR`, `RSTRING_LEN`, `rb_str_set_len`, `rb_str_resize` and `rb_str_cat` all go through it.
- What C wrote first goes back before the fetch, and the bytes past the length C has not revealed stay in the buffer.

The only way past the fetch is a struct C kept across a call into Ruby and then wrote the length into. With an in-place change by Ruby in between:

- ruby's String is Ruby's byte with C's bytes after it, because the buffer is the one both wrote;
- with this change mere-ruby's String is the same, and so is what C reads through `RSTRING_PTR` afterwards;
- before it, C's bytes replaced Ruby's change.

If Ruby's change moves ruby's buffer (`replace`, for one), the kept pointer is dangling in ruby too.

An earlier version marked each String the interpreter had not written since the sync, and refused MR_STR_CAT without the mark. That needed a check in `sput` and `str_push`, the String store's hot paths, and cost a loop of String writes 0.21%. A build that ignored the mark passed every contract. The one case the mark could change is the kept-struct one above, where it made the result differ from ruby's. So it was dropped.

### Why the cached answers are not kept on their own

They are most of the instructions saved (below). But the interpreter can keep them only when it knows the new bytes are the old ones with more after them. Under MR_STR_SET it would have to compare the whole String to find that out. MR_STR_CAT is that knowledge, from the side that already has it: C's hash of the synced part.

## Checked

Mere 9dec2ff6, reference ruby 4.0.10. The base is main 491cc5ca; for the Linux numbers it is main f09341c9, which differs from it only in corpus programs.

- **capi_check.** On the evaluator and with `--vm`, 444 contracts pass on both sides, also under collection stress, and each negative control fails. The new contracts build a String 32 KiB at a time with `rb_str_cat`, Ruby seeing it after each piece:
  - with Ruby writing it once in between: `<<`, `[]=`, `replace`, `force_encoding`, `clear`, and a write to a dup only;
  - with C writing it once in between: a byte in what was there, `rb_str_set_len`, `rb_str_resize`;
  - starting from a String Ruby made, and from an unfrozen dup of a frozen one;
  - a data object's String appended to in calls with collections between, marked by its dmark;
  - one a stopped Fiber holds across collections, appended to after;
  - the kept-struct case above, including what C then reads through `RSTRING_PTR` and a byte it writes there.

  On main's interpreter the kept-struct contract fails, and the others pass.
- **Mutants.**
  - A build that sends the tail without checking the synced part's hash fails the contracts.
  - A build whose MR_STR_CAT appends the bytes twice fails them as well, so the contracts do go through MR_STR_CAT.
- `run_corpus.sh --both`: the gates, then 1031/1031 with the hash index on and off. `MERE_RUBY_VM=1 run_corpus.sh --both`: 1031/1031.
- capi_spec_check: 2420 of 2602, the recorded count. capi_mkmf_check passes. capi_gem_check: seventeen gems give the same output on both sides. headers_check: 194 headers, 10 patched, 22 vendored sources unchanged.
- **Instructions** (macOS, the loop alone with start-up subtracted, median of three, alternating). "No cache" is this change with MR_STR_CAT dropping the cached answers (`sset`), for comparison:

  | loop | this change | no cache |
  |---|---|---|
  | `Buffer#read` 2 MiB from an IO ×100 | −68.0% | −1.1% |
  | `Buffer#read` 4,000 B ×20,000 | +0.06% | +0.14% |
  | `Buffer#read` 100 B ×50,000 | +0.02% | +0.05% |
  | `Unpacker#feed` 100 B ×100,000 | +0.19% | +0.27% |
  | msgpack `to_s` of 100 B ×100,000 | +0.05% | +0.10% |
  | String writes in Ruby (`<<`, `[]=`, `replace`, `clear`) ×300,000 | +0.22% | +0.21% |

  The small loops do not reach the new path; the rest is code layout.
- **Peak, macOS** (`Buffer#read` 2 MiB from an IO, the run's maximum RSS; the machine was shared, so the runs alternate):

  | | main | this change | no cache |
  |---|---|---|---|
  | ×30, `MERE_RUBY_GC_TIGHT=1`, 5 runs | median 373 MiB (312–374) | 350 (339–367) | 350 (315–430) |
  | ×100, default, 7 runs | median 649 MiB (632–750) | 616 (421–825) | — |

  With the default collector the peak depends on when the collections fall, and the runs spread over 400 MiB. The footprint medians of those seven are 639 (main) and 679 MiB.
- **Linux** (docker, Debian, ruby:4.0.10, clang 19, aarch64; peak RSS from GNU time):
  - `Buffer#read` of 2 MiB from an IO ×100: 94 MB on both. User CPU 0.34–0.44 s on both over five runs each, plus one main run at 0.65 s.
  - The specs, with their random seeds fixed in a copy for the measurement (they pick a new one every run), five runs alternating:

    | | main: median (range) | this change: median (range) |
    |---|---|---|
    | buffer_io_spec | 1,291 MB (1,106–1,386) | 1,195 MB (1,118–1,466) |
    | buffer_spec | 1,254 MB (1,167–1,753) | 1,136 MB (1,071–1,269) |
    | whole suite | 2,887 MB (2,758–3,631) | 2,677 MB (2,491–4,114) |

    Within the runs' own spread. The peaks are the interpreter's part described above.

## Left

- **The interpreter's part.** The String store's arenas keep the bodies of Strings that died or were replaced until a page is compacted. That is most of the buffer specs' memory, and the suite still peaks over CI's 2 GiB.
- **The fetch after every call into Ruby.** C fetches a String it holds again even when the interpreter has not changed it. Here that makes the interpreter build the whole body at every crossing, and the C API hand all of it over.
- **The write-back hashes the whole String at every crossing**, as before.
