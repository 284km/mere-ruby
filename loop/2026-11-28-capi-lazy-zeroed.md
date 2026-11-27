# C API: a big String C makes empty is made in its struct

After #386, msgpack's packer spec still peaked at 1.6–2.1 GB on Linux (ruby: 0.37 GB), and the whole suite at 2.5–3.2 GB. The memory at the peak was big Strings living in several copies at once. This removes two of the copies for the String C makes empty and then writes.

## What was at the peak

The RSS was read at each step of the packer callbacks (Linux, after #386):

- **Each 6 MB String written.** Ruby grows by 6 MB, mere-ruby by 23 MB. msgpack keeps a big String by reference: it calls `rb_str_dup` and uses the dup's RSTRING_PTR. Here that is the String, the dup's copy in the interpreter and the dup's struct. CRuby's dup shares the bytes. That is left for later.
- **Each return from a nested level.** Ruby grows by about 6 MB, mere-ruby by 100–300 MB. The recursive packer turns each level's whole buffer into one String with `msgpack_buffer_all_as_string`: `rb_str_new(NULL, n)`, then a write through RSTRING_PTR. On mere-ruby those bytes lived four times over:
  - zeroed in transit;
  - a String of zeros in the interpreter;
  - fetched back into the struct and written there;
  - written back into a new String in the interpreter.

## What changed

`rb_str_new(NULL, n)` with n of 64 KiB or more (string.c `make`) now calls `mr_string_new_zeroed` (mirror.c):

- The interpreter makes an empty String.
- The n zero bytes are made in the struct's own buffer, where C is about to write them.
- The struct is watched (`touch`). Its hash is not the hash of what the interpreter has.

So at the next crossing the bytes go to the interpreter as any write C makes does. `mr_up` flushes the watched structs before every request that is not a read, and at the end of the call, so Ruby never sees the String empty. That leaves two copies, the struct and the interpreter's String, where there were four.

Smaller Strings are made as before. The only change for them is one comparison.

## Checked

Mere 9dec2ff6, reference ruby 4.0.10. The RSS and instruction figures were taken on #386's head (d10fa183) + this change, before main moved; the checks below were run again on main (7fd8c47e) + this change.

Linux (docker, Debian, ruby:4.0.10, clang 19, aarch64). Peak RSS from GNU time, three rounds each:

| | packer example peak | whole suite peak | suite time |
|---|---|---|---|
| main (c913da27) | 1,589 / 1,831 / 2,140 MB | 2,572 / 3,350 / 3,618 MB | 122.9 / 129.7 / 131.5 s |
| #386 | 1,589 / 1,917 / 2,026 MB | 2,458 / 2,756 / 3,219 MB | 116.7 / 122.3 / 129.8 s |
| this | 1,448 / 1,537 / 1,663 MB | 2,495 / 2,554 / 2,615 MB | 105.7 / 108.5 / 108.9 s |

macOS, the packer example on the evaluator: it ends at 593 / 618 MB (#386: 829–868 MB).

- **Small Strings** (macOS, instructions of the loop alone with start-up subtracted, median of three, alternating with #386's build):
  - `to_s` of 100 B ×100,000: +0.11%
  - `Unpacker#feed` 100 B ×100,000: +0.14%
  - 1 in 16 of 200 B ×100,000: +0.16%
  - `to_s` of 4,000 B ×50,000: +0.66%. That is +0.3% of the whole run, the same in all three runs. The small path gains one comparison, so the rest is the code's layout.
- **capi_check.** On the evaluator and with `--vm`, 426 contracts pass on both sides, also under collection stress, and each negative control fails. The new contracts:
  - C writes the first half of a big `rb_str_new(NULL, n)`, Ruby reads it, C writes the second half, and Ruby reads both.
  - The same, then `rb_str_resize` to a quarter, `rb_str_set_len` and `rb_str_modify`, each with a write after it.
  - A data object holds one alone, marked by its dmark, across collections.
  - A stopped Fiber holds one across a collection.
  - Twelve are made in a row, with collections between them.
- **A build that does not watch the new struct** (so its bytes never reach the interpreter) fails these contracts.
- **The eleven corpus programs that use a native extension** match ruby under `MERE_RUBY_GC_STRESS=1` on the evaluator and on the VM.
- `run_corpus.sh --both`: the gates, then 1029/1029 with the hash index on and off. `MERE_RUBY_VM=1 run_corpus.sh --both`: 1029/1029.
- capi_spec_check: 2420 of 2602, the recorded count. capi_mkmf_check passes. capi_gem_check: seventeen gems give the same output on both sides. headers_check: 194 headers, 10 patched, 22 vendored sources unchanged.

## Left

- **Sharing the bytes of `rb_str_dup` / `rb_str_new_frozen` for big Strings.** That is the +17 MB per write above.
- **The write-back still passes through transit.** The bytes are in transit once more while they are sent.
- **The whole suite still peaks at about 2.5 GB on Linux**, over CI's 2 GiB. This example is not the only part of it.
