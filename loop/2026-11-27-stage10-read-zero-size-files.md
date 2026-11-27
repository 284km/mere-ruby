# A path that gives bytes without a size is read to its end

Found while measuring `test_complemented_method_entry_memory_leak`: `File.read("/proc/self/status")` answered `""` on Linux. ruby reads such a file to its end.

The interpreter's whole-file read is Mere's `read_file`, which takes a regular file's size and reads that many bytes. That is right for a file on a disk and wrong for everything that gives bytes without having a size:

- A file in /proc or /sys is a regular file of size 0. It read as `""`.
- A pipe has no size and no seek. That covers `/dev/stdin` behind a pipe, `/dev/fd/N` of an `IO.pipe`, and a FIFO. On macOS, `echo hello | mere-ruby -e 'p File.read("/dev/stdin")'` failed ("mere-ruby: failed"). Of seven ways to read it whole or by lines, two failed, two raised StandardError and three died of a segmentation fault: `File.readlines`, `IO.readlines` and `File.foreach`.

## The change

- `read_path_whole` (m_state) reads a path's bytes to its end. A regular file with a size goes through `read_file`, as before. Anything else is read through a descriptor until it gives nothing more.
- `File.read`, `File.binread`, ARGF over files, the main script and `load` read through it. `File.read`'s arm already stat'ed the path for its directory check (dir_there), and that one stat now answers both questions: a third stat cost a seventh of a loop of small reads.
- A File over such a path reads it once (`file_obj_stream`). A File here is a path and a position, and every read opens the path again at the position. The line reader reads ahead and seeks back over what it did not use, so a pipe's second line was gone. Now the first read keeps the bytes on the object (`__f_whole`), and every later read, `eof?` and seek from the end uses them. This applies to a pipe, and to a regular file of size 0 that has bytes after all.
  - A regular file that is really empty is not kept: a Tempfile written later, or a log followed as it grows, still sees what is written.
  - A character device is not kept either: `/dev/zero` has no end to read to.

With a length, `File.read` and `File.binread` read such a path only as far as the offset and the length reach (`read_path_prefix`). A character device has no end: `File.read("/dev/urandom", 16)` read to the end of a device that has none, and never returned (review, Major). ruby answers its 16 bytes. And with the review's corpus lines, two more of ruby's answers came in:

- an offset is a seek, which a pipe refuses -- Errno::ESPIPE "Illegal seek @ rb_io_seek", even for an offset of 0;
- a read with a length is BINARY, as ruby tags it, the length possibly ending mid-character. Of a regular file it was UTF-8 on main too.

The refusals of a negative length or offset now come before the read (second review, Major). `raise_exc` records the exception and returns, so the arm went on to read: `File.read("/dev/zero", -1)` took the -1 for "no length", read a device without an end and never returned. ruby and main raise ArgumentError at once. The order is ruby's, asked of the reference for File and IO, read and binread, over /dev/zero, a pipe and a regular file:

- `read` refuses a negative offset first (ArgumentError);
- then the seek: a pipe refuses any offset (ESPIPE). `binread` seeks to a negative offset as well: a regular file refuses it (EINVAL "@ rb_io_seek", which this arm wrote without the "@ rb_io_seek"), and a character device takes it;
- a negative length comes last (ArgumentError).

`IO.read` is the prelude's. It refused a negative length before the offset and before the seek, and `File#seek` here does not refuse a pipe, so `IO.read(pipe, -1, 0)` answered ArgumentError where ruby answers ESPIPE. It now refuses the offset, asks `File.pipe?` when an offset is given, seeks, and then refuses the length. (`File#seek` on a File over a pipe still moves without ESPIPE; that is outside this change.)

A length or an offset that is not an Integer was taken for "none given" (third review, Major). The early refusals and the length looked only at an Integer, so `File.read("/dev/urandom", -1.0)`, an object whose `#to_int` answers -1, and `File.read("/dev/urandom", "bad")` read a device without an end. main answered "" at once; ruby raises ArgumentError and TypeError. Now `nil` (or nothing) is "none given", and anything else is converted as ruby's NUM2LONG converts it, before anything is read (`file_read_num`):

- a Float truncates;
- `#to_int` is asked, and an answer that is not an Integer is a TypeError naming it;
- a String is a TypeError ("no implicit conversion from string" for binread's offset, an off_t);
- a Bignum is a RangeError.

`binread` converts the length first, `read` the offset first. `IO.read` (the prelude's) converts the length after the open and the seek, as ruby does.

A Float was truncated without a look at its range (fourth review, Major). `File.read("/dev/zero", Float::INFINITY)` and `File.binread("/dev/zero", 1e100)` became a length past any device and read without an end; main answered "" (wrong, but at once). ruby raises a RangeError before anything is read. `file_read_num` now refuses NaN, the infinities and a Float outside a long with ruby's RangeError: "float Inf out of range of integer", "float NaN ...", "float 1e+100 ..." (in `%-.10g`).

An offset that is an off_t says "long long" instead, except on Linux, where an off_t is a long. These offsets are binread's, `#seek`'s, `#sysseek`'s, `#advise`'s and `IO.write`'s.

The prelude's readers took a Float the same way. `IO.read`, `IO#read`, `#sysread`, the line readers' limit, `#seek`, `#sysseek`, `#advise` and `IO.write`'s offset all converted through `__fd_long(__fd_int(x))`. A Float infinity there was a FloatDomainError, and one past a long was "bignum too big". They now go through `IO.__fd_num`, which checks a Float first. Two more places convert a Float through it now:

- `File#readpartial`, which handed the Float to the builtin as it was and answered a read;
- `IO#read_nonblock`, which called `to_int`.

An offset was reached by reading the bytes before it (fifth review, Major). `read_path_prefix` read the offset and the length from byte 0 and dropped the offset's bytes. `File.read("/dev/urandom", 0, 16)` read 16 bytes and then answered nil at the end of what it had read; ruby and main answer "". `File.read("/dev/urandom", 0, 2**40)` set out to read 1 TiB for a read of nothing, and did not return. `File.binread`, `IO.binread` and `File#pread` (which reads through `File.binread`) did the same. Now:

- A read with a length opens the path, seeks to the offset and reads at most the length (`read_path_at`). A character device takes the seek. A FIFO is refused before, by its stat, and the order of the refusals is as before.
- A length of 0 reads nothing and is "", at any offset, past the end too. A regular file read with a length of 0 at or past its end answered nil, on main (6d2cb190) as well.
- A regular file with a size is read the same way when a length is given, so a few bytes of a big file no longer read all of it.

A File reopened onto another path kept what it had read of the old one as a stream (third review, Major). Read over a pipe and then reopened onto a file, it answered the pipe's "old\n" again. `__f_reopen` now drops `__f_whole`, the bytes and the mark that the path was not a stream alike.

A File over a pipe whose writer keeps it open waits for the writer to close it at its first read, since that read takes the whole of it. ruby's `gets` there answers as each line arrives. Before, the second line was lost.

`read_file` is still used where the path is known to be regular:

- File.write's read of the old content (with an offset or "a");
- `File#truncate`;
- the size fallback (`fsize_of`; ruby's File.size of a /proc file is 0 too);
- `require`;
- `-c` / `--dump` of a script;
- the backtick's capture files;
- `/etc/localtime`.

## Corpus 838

Corpus 838 covers:

- a pipe behind `/dev/fd/N`, read by `File.read`, `File.binread` (BINARY), `IO.read`, `File.read` with a length, `File.readlines`, `File.foreach`, `File.open(&:read)` and `gets`, and an empty pipe;
- regular files: whole, with a length and an offset, empty, empty with a length, a directory (EISDIR) and a missing one (ENOENT);
- character devices with a length: `/dev/urandom` (16 and 8 bytes), `/dev/zero` (with an offset, and with a length of 0), and the encodings of reads with and without a length;
- a pipe read with an offset, and with an offset of 0: ESPIPE;
- a negative length, a negative offset and both, for `File` and `IO`, `read` and `binread`, over `/dev/zero`, a pipe and a regular file;
- lengths and offsets that are not Integers: a Float, an object with `#to_int` (answering -1, 2, and a String), a String, nil and a Bignum;
- Floats that have no long, as a length and as an offset, for `File` and `IO`, `read` and `binread`, and for `#read`, `#readpartial`, `#sysread`, `#read_nonblock`, `#gets`, `#seek` and `#sysseek`: the two infinities, NaN, 1e100, -1e100, 9.3e18 and 2**63;
- a length of 0 and a length of 3 at offsets 0, 16 and 2**40 of `/dev/urandom` and `/dev/zero`, and lengths of 0 and 2 near, at and past the end of a regular file, for `File.read`, `File.binread`, `IO.binread` and `IO.read`, and `File#pread` at 2**40;
- a File read over a pipe and then reopened onto a file;
- a Tempfile written and read back, a log opened empty and appended to twice while open, `w+` written and read back;
- line, length and `eof?` reads mixed on one File, and a seek from the end.

It matches ruby on both engines, and under GC stress on both. main (6d2cb190) answers the first pipe reads wrongly and then stops with a segmentation fault at its fifth line.

On Linux, `/proc/self/status` (read, binread, IO.read, readlines, foreach, open and read, gets and eof?), `/proc/self/cmdline` and `/proc/sys/kernel/ostype` match ruby 3.4 on both engines. main answered six of the ten wrongly.

## Numbers

Instructions: main (3fbe3921) against this branch on 391b560e, median of three alternating runs, Mere 9dec2ff6. Neither side's file reading changed in between. The file is 20,000 lines; the small one is 10 lines.

| program | evaluator: main | here | VM: main | here |
|---|---|---|---|---|
| `File.foreach` over the file, 5 times | 317.6 G | 317.7 G | 319.2 G | 320.7 G |
| `File.readlines` of it, 5 times | 319.3 G | 320.0 G | 321.4 G | 321.6 G |
| `gets` through it, 3 times | 196.9 G | 197.0 G | 197.1 G | 197.3 G |
| `File.read` of the small file, 20,000 times | 9.597 G | 9.577 G | 9.540 G | 9.619 G |
| `File.open`, `read(100)` twice and `eof?`, 300 times | 1.694 G | 1.720 G | 1.690 G | 1.714 G |

The last row is the one that pays: +1.5%. It is one stat per File object at its first read, to tell a pipe from a file -- about 85,000 instructions an open. Every other row is within 0.5%.

(Reading by lines costs about 3 million instructions a line on both sides. That is the line reader's own, and not this change's.)

## Checked

On 391b560e:

- `run_corpus.sh`: 1013/1013.
- `vm_corpus.sh`: all 1013 programs on the VM, 0 fallback, 0 FAIL.
- vm_check: 246/246.
- The collector's root check.
- `tools/loop_rss_check.sh`: all 14 loops within their bounds.
- Linux (arm64, docker): /proc as above, both engines.
- After the review fix: the same corpus, vm_corpus, vm_check, root check and loop_rss_check again, all passing.
- After the second review fix, merged with main 9547d96b: `run_corpus.sh` 1024/1024, `vm_corpus.sh` all 1024 on the VM with 0 fallback and 0 FAIL, vm_check 246/246, the root check, and `tools/loop_rss_check.sh` (14/14).
- After the third review fix, merged with main ad289755: `run_corpus.sh` 1027/1027, `vm_corpus.sh` all 1027 on the VM with 0 fallback and 0 FAIL, vm_check 246/246, the root check, and `tools/loop_rss_check.sh` (14/14).
- After the fourth review fix, on 8b1c2ed5: `run_corpus.sh` 1027/1027, `vm_corpus.sh` all 1027 on the VM with 0 fallback and 0 FAIL, vm_check 246/246, the root check, and `tools/loop_rss_check.sh` (14/14).
