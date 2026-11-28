# C API: what C appends to a big String goes to the interpreter as the tail

After #390, msgpack's whole suite still peaked at 2.65–2.89 GB on Linux. Two spec files besides packer_spec made most of it:

| spec file alone (Linux, MB) | mere-ruby | ruby |
|---|---|---|
| cruby/buffer_io_spec | 1,899 | 96 |
| packer_spec | 1,836 | 369 |
| cruby/buffer_spec | 1,714 | 138 |
| the other 11 | 112–266 | 24–26 |

Most of the buffer specs' memory is the interpreter's, not the C API's. Their largest example, buffer_io_spec's 'random read', does the same with `StringIO#read` in place of `MessagePack::Buffer`, with no C extension. It still ends at 200–250 MB on both engines, against ruby's 15 MB, with 6.5 MB of live Strings. That part is the String store's arenas, which do not shrink after big Strings are made and dropped. It is handed on separately. This change is the C API's own part of it.

## What the C API's part was

A ledger of malloc's blocks of 64 KiB or more, by caller with a call chain of seven frames (LD_PRELOAD, Linux), on 'random read' with `GC.start` in each round:

- The mirror's own buffers and transit: 160 MB allocated in all, none of it held at the end.
- `write_back → mr_up → mu_capi_up → mu_sput → __lang_region_alloc_aligned`:
  - 832 MB allocated in all;
  - 189 MB live at the peak;
  - 154 MB still live after `GC.start`, while the String store counted 5 MB live;
  - the same rounds without the C extension: 357 MB in all.

msgpack's `Buffer#read(n)` from an IO starts from `rb_str_buf_new(0)`. It then appends 32 KiB at a time with `rb_str_cat`, calling `io.readpartial` between appends. `rb_str_cat` appends in the String's struct, which is then watched. So at every `readpartial` the whole String so far went back with `MR_STR_SET`, and the interpreter stored a new body each time. For a 1.4 MB read that is 44 write-backs and about 30 MB of bodies. The old ones stay in the page's arena until the page is compacted.

## What changed

- **mirror.c.** A String's struct keeps the length it last synced with the interpreter (`synced`). At a write-back, MR_STR_CAT sends only the bytes past that length when:
  - that length is 64 KiB or more;
  - the String only grew;
  - its first `synced` bytes still hash as they did at the sync.

  Otherwise all of it goes, as MR_STR_SET, as before. The hash now takes the length at its end (`hash_end`) instead of at its start. One pass therefore gives both the hash of what the String was and of what it is (`hash_two`). The first version hashed the synced part a second time, and that made the same loop slower on Linux.
- **main.mere.** MR_STR_CAT appends the bytes with `str_push`, which is String#<<'s queue, so a String built this way costs amortized linear work. It does so when the String is the length C says. Otherwise it refuses, and C sends all of it.

### Why the interpreter does not check that Ruby left the String alone

A write Ruby made since the sync is already in the struct's first `synced` bytes:

- C reaches the bytes through `rb_mere_string`, which fetches the String again after any call into Ruby.
- `RSTRING`, `RSTRING_PTR`, `RSTRING_LEN`, `rb_str_set_len`, `rb_str_resize` and `rb_str_cat` all go through it.
- What C wrote first goes back before the fetch, and the bytes past the length C has not revealed stay in the buffer.

The only way past the fetch is a struct C kept across a call into Ruby and then wrote the length into. With an in-place change by Ruby in between:

- ruby's String is Ruby's byte with C's bytes after it, because the buffer is the one both wrote;
- with this change mere-ruby's String is the same;
- before it, C's bytes replaced Ruby's change.

If Ruby's change moves ruby's buffer (`replace`, for one), the kept pointer is dangling in ruby too.

An earlier version marked each String the interpreter had not written since the sync, and refused MR_STR_CAT without the mark. That needed a check in `sput` and `str_push`, the String store's hot paths. A build that ignored the mark passed every contract. The one case the mark could change is the kept-struct one above, and there it made the result differ from ruby's. So it was dropped.

## Checked

Mere 9dec2ff6, reference ruby 4.0.10. The base is main 491cc5ca; for the Linux numbers it is main f09341c9, which differs from it only in corpus programs.

- **capi_check.** On the evaluator and with `--vm`, 444 contracts pass on both sides, also under collection stress, and each negative control fails. The new contracts build a String 32 KiB at a time with `rb_str_cat`, Ruby seeing it after each piece:
  - with Ruby writing it once in between: `<<`, `[]=`, `replace`, `force_encoding`, `clear`, and a write to a dup only;
  - with C writing it once in between: a byte in what was there, `rb_str_set_len`, `rb_str_resize`;
  - starting from a String Ruby made, and from an unfrozen dup of a frozen one;
  - a data object's String appended to in calls with collections between, marked by its dmark;
  - one a stopped Fiber holds across collections, appended to after;
  - the kept-struct case above.

  On main's interpreter the kept-struct contract fails, and the others pass.
- **Mutants.**
  - A build that sends the tail without checking the synced part's hash fails the contracts.
  - A build whose MR_STR_CAT appends the bytes twice fails them as well, so the contracts do go through MR_STR_CAT.
- `run_corpus.sh --both`: the gates, then 1031/1031 with the hash index on and off. `MERE_RUBY_VM=1 run_corpus.sh --both`: 1031/1031.
- capi_spec_check: 2420 of 2602, the recorded count. capi_mkmf_check passes. capi_gem_check: seventeen gems give the same output on both sides. headers_check: 194 headers, 10 patched, 22 vendored sources unchanged.
- **Instructions** (macOS, the loop alone with start-up subtracted, median of three, alternating with main's build):

  | loop | instructions |
  |---|---|
  | msgpack `to_s` of 100 B ×100,000 | +0.23% |
  | `Unpacker#feed` 100 B ×100,000 | +0.16% |
  | `Buffer#read` 100 B from an IO ×50,000 | +0.20% |
  | `Buffer#read` 4,000 B from an IO ×20,000 | +0.17% |
  | `Buffer#read` 2 MiB from an IO ×100 | −69.6% |
  | String writes in Ruby (`<<`, `[]=`, `replace`, `clear`) ×300,000 | +0.12% |

  The small loops do not reach the new path. They pay a length test at each write-back, and the rest is code layout. The interpreter's mark of the earlier version cost the String-writes loop +0.33%.
- **Linux** (docker, Debian, ruby:4.0.10, clang 19, aarch64; peak RSS from GNU time):
  - 'random read' outside rspec, fixed seed, `GC.start` each round, three runs:
    - before: peak 509 / 540 / 648 MB, end 509 / 459 / 518 MB;
    - after: peak 466 / 530 / 560 MB, end 265 / 351 / 410 MB.
  - `Buffer#read` of 2 MiB from an IO ×100: 94 MB on both. The time is 0.54–0.57 s before and 0.52–0.56 s after, with one run of 0.87 s.
  - The specs, with their random seeds fixed in a copy for the measurement (they pick a new one every run), five runs alternating:

    | | before: median (range) | after: median (range) |
    |---|---|---|
    | buffer_io_spec | 1,230 MB (1,088–1,727) | 1,223 MB (1,115–1,538) |
    | buffer_spec | 1,189 MB (1,034–1,323) | 1,206 MB (953–1,281) |
    | whole suite | 2,938 MB (2,400–3,137) | 2,951 MB (2,380–3,252) |

    No difference beyond the runs' own spread. The peaks are the interpreter's part described above.

## Left

- **The interpreter's part.** The String store's arenas keep the bodies of Strings that died or were replaced until a page is compacted. That is most of the buffer specs' memory, and the suite still peaks over CI's 2 GiB.
- **On macOS, the 2 MiB loop's peak is higher:** 846 MiB at most against main's 695. The pieces appended wait in `str_push`'s queue until a collection folds them in. On Linux the peak is the same as before.
- **The write-back still hashes the whole String at every crossing**, as it did before.
