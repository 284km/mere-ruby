# A File over a pipe has no position

A pipe has no position. ruby's File over one (a pipe behind `/dev/fd/N`, a FIFO) refuses `#seek`, `#pos`, `#tell`, `#pos=`, `#rewind` and `#sysseek` with Errno::ESPIPE, each naming its own entry point (`rb_io_seek`, `rb_io_tell`, `rb_io_set_pos`, `rb_io_rewind`, `rb_io_sysseek`). Here every one of them answered as if the pipe were a file: `seek(1)` answered 0, `pos=` 1, `rewind` 0. This came up in #373's review: `IO.read(pipe, -1, 0)` had to ask `File.pipe?` itself, because `File#seek` did not refuse.

## The change

- `file_is_fifo` (main.mere) asks a File's path once whether it is a pipe, and keeps the answer on the object (`__f_fifo`).
- The builtin `#pos`, `#tell` and `#rewind` of a File refuse a pipe.
- `__f_seek` takes a third argument, the name of the caller: `#seek` gives "seek" and `#pos=` gives "set_pos", and a pipe is refused under that name. `#pos=` no longer goes through `#seek`, so that its refusal names `rb_io_set_pos`. It does what `#seek(off, 0)` did.
- `#sysseek` asks `__f_pipe?` through `__f_espipe` before it seeks.

The prelude's own readers move a File's position as well: the line reader gives back what it read ahead, `read(n)` past an invalid byte, a BOM skipped, and `dup` and `reopen` placing the copy. A File over a pipe reads through them too, by lines and by lengths (#373). So they no longer call the public `#pos` and `#pos=`. They call `__io_tell` and `__io_set_pos`:

- on IO, these are `#pos` and `#pos=`, as before;
- on File, they are the builtin's position (`__f_tell`) and `__f_seek` with no name, which does not refuse a pipe.

## What is left as it is

After a refused `#rewind`, ruby drops what it had read ahead: `[f.gets, (f.rewind rescue nil), f.gets]` over "a\nb\n" answers `["a\n", nil, nil]`. Here the second `gets` answers "b\n". A refused `#seek` loses nothing in ruby either, so only `#rewind` differs. Corpus 840 leaves it out.

## Corpus 840

Corpus 840 covers:

- a File over a pipe:
  - `seek` (SET, CUR, END, and a Symbol), `pos`, `tell`, `pos=`, `rewind` and `sysseek`, each refused under its own name;
  - a read, a refused seek, and the rest read after it;
  - `gets`, a refused `pos`, and the lines after it;
  - lines and lengths mixed, `each_line`, `getc` and `ungetc`, and `dup`;
- `IO.pipe`'s own reader, for `seek` and `pos`;
- a regular file:
  - `gets` and `pos`;
  - `seek` (SET and END);
  - `pos=`, `rewind` with `lineno`, and `sysseek`;
  - `dup`, `reopen` onto another File, a BOM skipped, and reads by length.

It matches ruby on both engines. main answers every refusal with a position, and then crashes at the first read after a seek. main has no #373 yet, and without it a File over a pipe is not read correctly.

## Numbers

Instructions retired for the whole program, in billions, the median of three runs taken alternately. The old side is #373's head (`81df71f9`), which this branch is built on. Both sides are built with the same Mere.

| program | evaluator: old | new | VM: old | new |
|---|---|---|---|---|
| `gets` over 1,000 lines | 4.284 | 4.108 | 4.297 | 4.136 |
| `seek`, `pos` and `rewind` of a regular file, 20,000 times | 6.673 | 6.701 | 6.680 | 6.712 |
| `File.open`, `read(100)` and `read(50)`, 2,000 times | 4.868 | 4.866 | 4.859 | 4.857 |
| `File.read` of a small file, 20,000 times | 9.530 | 9.545 | 9.580 | 9.575 |
| `File.open`, `read(100)` twice and `eof?`, 300 times | 1.717 | 1.710 | 1.719 | 1.718 |

`gets` is 4% cheaper: the line reader's give-back now reads and moves the builtin's position directly, where it used to go through the prelude's `#pos=` and `#seek`. `seek` and `pos` cost +0.4%: one stat for each File, the first time, and then a lookup each time.

The first version refused in `#seek` through a prelude method of its own (`__f_espipe`), and that cost +12% on the `seek` loop. The refusal is now in `__f_seek`, which `#seek` called already.

## Checked

CHECKED
