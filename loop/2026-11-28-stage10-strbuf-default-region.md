# A StrBuf is made in a region of its own

A loop that makes big Strings and lets them go kept its memory, on both engines. This is the msgpack buffer spec's loop with the C extension taken out:

    r = Random.new(12345)
    50.times { f = []; r.rand(4).times { f << r.bytes(r.rand(1024*1400)) }; io = StringIO.new(f.join); f.each { |s| io.read(s.size) }; GC.start }

On macOS its peak memory footprint was 324 MB on the evaluator and 334 MB on the VM; ruby's is 43 MB. On Linux the peak was 215 to 264 MB, and 202 to 252 MB was still there at the end, where ruby's is 15 MB. What lived at the end was 6.5 MB.

## What kept the memory

Two things, measured on macOS.

**The default region.** It held 6 blocks, 264 MB, of which 208 MB had been handed out; what the interpreter needs to start is 40 MB. Mere never gives the default region back.

`strbuf_new ()` takes its region from its type. A StrBuf made outside every `region NAME { ... }` block gets the default one (`__heap`, which the C backend emits as `&__lang_default_region`). A StrBuf's buffer grows to the size of what it builds. So every call that built its result in a StrBuf left a buffer of the result's size behind, for the rest of the run, after the result itself had been let go.

`Random#bytes` and `Array#join` build their result that way, and the program above calls both. Building with `mere -c --region-sites` named the lines that fill the default region, for one operation at a time.

**The current String page.** That is the other part, and this change does not touch it. See "What is left".

## The change

Every StrBuf is made inside a region block, which hands out only the text:

    region JOIN { let jb = strbuf_new () in ...; (strbuf_to_str jb, enc) }

This is the form `encode_cps` already had (`region ENCB`, note 441).

- **By hand, where the change needed thought:**
  - `Array#join`;
  - `Random#bytes`;
  - `sub` and `gsub` with a String or a Hash;
  - `gsub` with a block, and the regex engine's `gsub`;
  - `tr`, `delete` and `squeeze`;
  - `String#inspect` (`esc_str_b`) and `reverse`;
  - `Array#inspect` and `Hash#inspect` (`join_inspect_w`, `join_pairs_w`);
  - `JSON.generate`.
- **Mechanically, the other 36 sites:** for a `let b = strbuf_new () in` with one `strbuf_to_str b`, the parenthesized group around it, or the rest of the function. These include `center` and `ljust`, `format`'s `%` directives, `dump`, `scrub`, `Integer#to_s` of a Bignum, the encodings' case maps and transcoders, the regex subject and pattern in other encodings, `File.read` of a range, and `Array#sum` of Strings.

`gsub` with a block also made a new Hash per match: the block's "no block", `(false, Nil, Nil, map_new ())`. Made outside a region block, it was the default region's too. `("ab" * 500_000).gsub(/a/) { "c" }` kept 50 MB of them. It could not go into a region, because its type is tied to the block's own. It is now made once per call, holding the env the block already has, as every other "no block" does.

## Numbers

### The default region, per operation

What ten calls added to the default region, per call. Each call worked on a 1 MB String, and the noise is about 51 KB.

| operation | main | this branch |
|---|---|---|
| `gsub` with a block | 53 MB | 0.5 MB |
| `gsub`, `sub`, `tr`, `reverse`, `squeeze`, `inspect`, `JSON.generate` | 1 MB | noise |
| `[s].to_s` | 2 MB | noise |
| `delete` | 0.5 MB | noise |
| `center`, `ljust` | 0.18 MB | noise |
| `Array#join` of two 1 MB Strings | 2 MB | noise |
| `Random#bytes(1_000_000)` | 1 MB | noise |

`split`, `lines`, `each_line` and `scan` added 0.5 to 4.5 MB too, but not as a StrBuf: see "What is left".

### The program above

Peak memory footprint on macOS, evaluator, by the number of turns. The middle column is with only `Array#join` and `Random#bytes` changed.

| turns | main | this branch |
|---|---|---|
| 25 | 283 MB | 192 MB |
| 50 | 324 MB | 307 MB |
| 100 | 434 MB | 311 MB |
| 200 | 714 MB | 315 MB |

On main the footprint grew with the turns. On this branch it stops growing. ruby's footprint for 200 turns is 48 MB. With every StrBuf changed, 50 turns peak at 264 MB on the evaluator and 219 MB on the VM.

On Linux (arm64, in docker) with every StrBuf changed, the peak RSS (VmHWM) and the RSS at the end (VmRSS) were:

| turns | engine | main: peak | main: end | this branch: peak | this branch: end |
|---|---|---|---|---|---|
| 50 | evaluator | 219 MB | 205 MB | 173 MB | 137 MB |
| 50 | VM | 250 MB | 223 MB | 177 MB | 142 MB |
| 200 | evaluator | 625 MB | 596 MB | 230 MB | 189 MB |
| 200 | VM | 619 MB | 588 MB | 227 MB | 171 MB |

ruby: a peak of 26 MB and 22 MB at the end for 50 turns; 27 MB and 15 MB for 200.

### Instructions

Instructions retired, in billions. Each figure is the median of three runs taken alternately, and both sides are built with the same Mere. A region is entered at each call now, so the first row is small Strings in a tight loop: `tr`, `delete`, `squeeze`, `reverse`, `inspect`, `sub`, `gsub` (String and block), `center`, `ljust`, `join`, `Array#inspect`, `Hash#inspect`, `Random#bytes(8)` and `format`, 100,000 times.

| program | evaluator: main | branch | VM: main | branch |
|---|---|---|---|---|
| small Strings, 15 operations | 39.880 | 40.120 | 36.268 | 36.546 |
| `JSON.generate`, a Bignum's `to_s`, 50,000 times | 25.446 | 25.421 | 25.145 | 25.143 |
| `loop_plain` | 23.402 | 23.421 | 12.665 | 12.657 |

The first row is 0.6% more on the evaluator and 0.8% more on the VM: a region at each call. The others are unchanged.

## Watching it

### tools/loop_rss_check.rb

Eleven new cases. Each makes a 32 KB result 4,000 times: `gsub` with a block, `gsub` with a String, `sub`, `tr`, `delete`, `squeeze`, `reverse`, `inspect`, `Array#to_s`, `Array#join` and `Random#bytes`. Their ratios of RSS after to RSS before:

| | main | this branch |
|---|---|---|
| evaluator | 2.08 to 4.01, all FAIL | 0.61 to 1.46 |
| VM | 1.97 to 3.98, all FAIL | 1.11 to 1.86 |

These cases are held on the evaluator, which is what `tools/loop_rss_check.sh` runs. CI does not run that script; the gate does.

On the VM the numbers depend on where the binary is run from. Run from `/tmp`, all eleven were 1.25 to 1.44. Run from the tree (`./mere-ruby`, with `lib/` beside it), three were over the bound, in the file's order, five times out of five (review): `gsub` with a String and `sub` at 1.86, and `Array#join` at 1.79. What started differs, and so does where the String pages fall.

It is not a leak. `gsub` with a String over 2,000, 4,000, 8,000 and 16,000 turns gave 1.39, 1.86, 1.58 and 1.19. Main gave 307, 440 and 683 MB as the turns grew; this branch gave 166, 158 and 119 MB. What the VM keeps is the current page (below), whose size depends on where a collection falls. So the VM is not watched by these cases until the current page is dealt with.

What this branch still keeps is bounded. `Array#join` over 2,000, 4,000 and 8,000 turns added 43, 41 and 49 MB. That is the current String page (below), and it is why the ratios are 1.4 and not 1.0.

`JSON.generate`, `split`, `lines`, `each_line` and `scan` are not cases yet. On this branch they are bounded too, but at 1.66 to 1.91: that is the current page and the collector's survivor list, below.

### tools/strbuf_region_check.py

`run_corpus.sh` runs it next to `iv_door_check.sh`. It reads the source, skipping comments and string literals, and keeps a stack of the `region NAME {` blocks open at each point. A `strbuf_new` with none open is reported, unless its function is allowed with a reason. Allowed:

- `lex_dstr_buf`: its StrBufs are typed as the one it is handed, which `lex_dstr_t` makes in `region DSTR`. A StrBuf of a region parameter is made in the region the caller passes.
- `pt_q`, `pt_e_inline` and `cli_parsetree`: `--dump=parsetree`, once a run. Its printers share one StrBuf type.

`unittest/harness_check.py` and `tools/runtime_load_path_check.py` copy `run_corpus.sh` into a repository of their own, with the source checks as stubs. They have a stub of this one too (review, Major): without it `run_corpus.sh` stopped before the corpus, and their corpus tests failed.

It reads the spelling, not the meaning: a function called from inside a region block is in that region at run time, and is still reported. Such a function goes in the allowed list, with its caller named.

So, after a build, it reads the emitted C too. Every function whose StrBuf is `mere_strbuf_new((&__lang_default_region))` in `mr.c` has to be an allowed one. There are three now: the `--dump=parsetree` printers. The lexer's StrBufs take the region their caller passes.

That is how a wrong allowance showed (review). `encode_cps_go` was allowed as "typed as `b`, under `region ENCB`", but the C made its one-character StrBufs, two of them, in the default region. They asked for EUC-JP's bytes of one character, for the EUC-JIS-2004 and stateless-ISO-2022-JP arms. That character's bytes are now a function of their own, `jis_family_char`, which the JIS family's arm uses too, and no StrBuf is made.

It fails as well:

- when it read no file or no function;
- when an allowance is no longer taken;
- when a file's braces or quotes do not balance by its end.

A check that read nothing, or read a file wrong, would pass everything.

## What is left

- **The current String page.** Strings live in pages of 4,096. A collection compacts a page to give back the bytes of the Strings that died in it, but not while a suspended stack points into the page's arena. The collector runs on a coroutine, and the program's stack, stopped below it, points into the page in use. In the program above, 42 of 51 compactions were refused, counted with a probe that is not in this change. The page grew to 44 to 54 MB before Mere's rule let a compaction through: it compacts under a pin once the arena has doubled since the first refusal (v0.1.651). The compaction then brought it back to 23 MB. That is the 50 to 68 MB of `str_store` after the last `GC.start`, where 6.5 MB lived. The next change tries keeping big Strings in arenas of their own.
- **The collector's survivor list.** `gc_str_surv` is a top-level Vec. Each time it grows, the copy it outgrew stays in the default region. That is what `split`, `lines` and `scan` added. It is a high-water mark, not a growth with the turns: `split` 5, 10, 20 and 40 times added 49, 53, 20 and 29 MB.
- **`JSON.generate`'s own region** handed out 131 KB per call for a 32 KB String. Its region gives that back at the call's end, but it is more work than the result needs.

Found in review, the same on main, and not this change's:

- `break` inside a `gsub` block answers the wrong value: ruby's is 9 and mere's is "a9c".
- `encode(..., undef: :replace)` grows by about 2.5 MB a call.

## Checked

On cb532798, which is main 491cc5ca and this branch:

- `run_corpus.sh` 1031/1031, with `tools/strbuf_region_check.py` among its checks.
- `vm_corpus.sh`: all 1031 programs on the VM, with 0 fallback and 0 FAIL.
- vm_check 246/246.
- The collector's root check.
- `tools/loop_rss_check.sh`: 26/26, the eleven new cases included.
- `tools/class_watermark_check.sh`.
- `tools/strbuf_region_check.py` reports a StrBuf made outside a region block in a file of its own, and nothing in one made inside.
- After the review fix: `python3 unittest/harness_check.py -v` (21 tests, `test_corpus_uses_selected_reference_and_both_index_modes` included) and `python3 tools/runtime_load_path_check.py -v` (8 tests, the corpus ones included), both OK.
- After the second review's fixes, on 02179425: `run_corpus.sh` 1031/1031 (`strbuf_region_check.py` reading `mr.c` too), `vm_corpus.sh` all 1031 on the VM with 0 fallback and 0 FAIL, vm_check 246/246, the root check, `tools/loop_rss_check.sh` 26/26 from the tree, and `tools/class_watermark_check.sh`. The JIS family's encoders (8 encodings, 15 characters) answer as main does. The check fails, as it should, on a file whose braces do not close, on reading no file, on an allowance no longer taken, and on a function missing from the allowed list in `mr.c`.
