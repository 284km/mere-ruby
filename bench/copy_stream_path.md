# Avoid copying the remaining path source on every chunk

`IO.copy_stream` wraps a path's bytes in an object that supplies 16-KiB chunks.
Its reader previously replaced its source string with a copy of the unread
suffix after every chunk. An N-byte file therefore copied approximately
N-squared / (2 * 16384) bytes just to discard prefixes.

Keep the source string and advance a byte cursor instead. The next read copies
only its requested chunk. This preserves the existing path/offset/length
selection, reusable output buffer and destination behavior. The path is still
loaded into memory once; this change does not implement descriptor streaming.

Measurements on macOS arm64, O2, Mere compiler
`991f299b20f18639713685fe3297e087ddc5b1d7`, CRuby source
`3e93b23afcec3433f6aecc34b5d832799d754238`, with unchanged 600-second / 2-GiB
process-family limits:

| Check on main dcbdbf0 | Before | With cursor |
| --- | --- | --- |
| 8-MiB path to a counting sink | 3.268 s, 1,615,088 KiB | 1.683 s, 196,208 KiB |
| Full unchanged `ruby/test_io.rb` | MEMORY_LIMIT at test 197/249, 152.555 s, 2,217,872 KiB | All 249 tests finish, 201.746 s, 889,312 KiB, no resource limit |

The failing case is `TestIO#test_copy_stream_socket7`: 30 copies of a 3,703,701-byte
file into a nonblocking UNIX socket, with a forked reader. In isolation it
reaches MEMORY_LIMIT after 9.845 seconds at 2,152,400 KiB. Replacing only the
source reader on that same baseline binary makes its 32 assertions pass.

The complete IO file retains one internal timeout (`test_select_memory_leak`)
and four skips. Running the other 248 tests on the unchanged baseline produces
the same five non-passing case names and outcome categories. Assertion totals
vary in the concurrency/leak tests. Bounded completion does not mean the full
file passes, and these local measurements are not an end-to-end Actions speedup.

`corpus/527_copy_stream_path_cursor.rb` checks binary bytes across chunk
boundaries, Pathname sources, offsets/lengths/EOF, repeated calls, path and
StringIO destinations, existing IO positions and recovery from a destination
exception. `bench/copy_stream_path.rb` checks an 8-MiB transfer without retaining
the destination; its optional argument sets the size in bytes.

The final branch also includes main's independently merged block-depth guard
(#49, main `666475d`). Its validation is recorded in the PR, separately from the
same-base before/after measurements above. No upstream test or CI resource
limit is changed.
