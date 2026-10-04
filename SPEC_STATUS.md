# mere-ruby — ruby/spec status

Byte-exact conformance against ruby/spec (the de-facto Ruby suite), swept by
`mspec/scoreboard.sh`. Not a pass/fail gate — a checked-in record of where
mere-ruby matches CRuby and where it does not, like the other alternative
implementations' tags files. Per-file DIFF/CRASH lists live in `mspec/tags/`.

- **MATCH** identical output under mere-ruby and ruby
- **DIFF** runs on both, output differs (fidelity gap — often an error message or a frozen check)
- **CRASH** mere-ruby aborts ON ITS OWN where ruby does not (missing feature)
- **SKIP** ruby itself does not run it here (mock/subprocess/platform — unmeasurable),
  including a file whose examples are all behind a guard: both sides ran zero, which agrees and measures nothing
- **SLOW** stopped by one of this harness's bounds — CPU seconds, wall clock or bytes —
  and so working, not aborting. The row in `mspec/tags/` names which bound answered.

Measured against **ruby 4.0.6** (tools/ref_ruby.sh). The reference is part
of the subject: a row measured against another release is not comparable with the
ones around it, and the difference reads as movement in mere-ruby.

⚠ **The shim is part of the subject too.** From 2026-09-29 it runs what mspec runs:
shared examples (`it_behaves_like`, 1781 lines that used to run nothing), the
platform / version / feature guards, mspec's before/after order, and its raise
matcher (message, `cause:` and the block). A row from before that date compared
fewer examples, so MATCH 2589 before it and 2221 on it are not the same question:
the 368 files were ones whose newly compared examples differed, not behaviour that
was lost. (From 2026-09-30 the shim's suppress_warning silences `$VERBOSE` and the
environment carries RUBY_EXE / RUBY_FLAGS, as mspec's do.)

⚠ **From 2026-09-30 a file in which the reference ran NO example is SKIP, not MATCH.**
Both sides printing zero agreed and measured nothing -- win32ole, the cgi that ruby 4.0
dropped, every platform-guarded Process file. 335 files moved from MATCH to SKIP at once,
so MATCH 2722 before it and 2410 on it are not the same question either.
| group | MATCH | DIFF | CRASH | SKIP | SLOW | total |
|---|---|---|---|---|---|---|
| language | 44 | 23 | 0 | 0 | 0 | 67 |
| core/string | 111 | 2 | 0 | 0 | 1 | 114 |
| core/array | 103 | 0 | 0 | 1 | 1 | 105 |
| core/hash | 68 | 1 | 0 | 0 | 0 | 69 |
| core/range | 31 | 2 | 0 | 2 | 0 | 35 |
| core/comparable | 7 | 0 | 0 | 0 | 0 | 7 |
| core/complex | 42 | 0 | 0 | 1 | 0 | 43 |
| core/env | 44 | 0 | 0 | 1 | 0 | 45 |
| core/exception | 36 | 3 | 0 | 0 | 0 | 39 |
| core/false | 9 | 0 | 0 | 0 | 0 | 9 |
| core/float | 47 | 0 | 0 | 3 | 0 | 50 |
| core/integer | 59 | 1 | 0 | 9 | 1 | 70 |
| core/kernel | 84 | 21 | 0 | 12 | 1 | 118 |
| core/matchdata | 28 | 0 | 0 | 2 | 0 | 30 |
| core/method | 18 | 4 | 0 | 4 | 0 | 26 |
| core/mutex | 7 | 0 | 0 | 0 | 0 | 7 |
| core/nil | 16 | 0 | 0 | 2 | 0 | 18 |
| core/numeric | 45 | 0 | 0 | 0 | 1 | 46 |
| core/queue | 13 | 2 | 0 | 0 | 0 | 15 |
| core/rational | 27 | 0 | 0 | 5 | 0 | 32 |
| core/sizedqueue | 13 | 3 | 0 | 0 | 0 | 16 |
| core/struct | 30 | 0 | 0 | 0 | 0 | 30 |
| core/symbol | 28 | 1 | 0 | 0 | 0 | 29 |
| core/threadgroup | 5 | 0 | 0 | 0 | 0 | 5 |
| core/true | 9 | 0 | 0 | 0 | 0 | 9 |
| core/unboundmethod | 11 | 4 | 0 | 5 | 0 | 20 |
| core/systemexit | 2 | 0 | 0 | 0 | 0 | 2 |
| core/proc | 17 | 6 | 0 | 2 | 0 | 25 |
| core/set | 54 | 0 | 0 | 1 | 0 | 55 |
| core/regexp | 21 | 3 | 0 | 0 | 0 | 24 |
| core/enumerable | 58 | 2 | 0 | 1 | 0 | 61 |
| core/module | 78 | 5 | 0 | 2 | 0 | 85 |
| core/filetest | 18 | 1 | 0 | 6 | 0 | 25 |
| core/data | 12 | 0 | 0 | 1 | 0 | 13 |
| core/math | 29 | 0 | 0 | 0 | 0 | 29 |
| core/basicobject | 10 | 4 | 0 | 0 | 0 | 14 |
| core/argf | 35 | 0 | 0 | 0 | 0 | 35 |
| core/class | 8 | 0 | 0 | 0 | 0 | 8 |
| core/encoding | 13 | 1 | 0 | 3 | 0 | 17 |
| core/enumerator | 18 | 2 | 0 | 0 | 0 | 20 |
| core/random | 10 | 0 | 0 | 0 | 0 | 10 |
| core/signal | 2 | 1 | 0 | 0 | 0 | 3 |
| core/objectspace | 6 | 0 | 0 | 1 | 0 | 7 |
| core/main | 6 | 1 | 0 | 0 | 0 | 7 |
| core/gc | 9 | 2 | 0 | 0 | 0 | 11 |
| core/binding | 8 | 4 | 0 | 0 | 0 | 12 |
| core/refinement | 6 | 1 | 0 | 1 | 0 | 8 |
| core/warning | 4 | 1 | 0 | 0 | 0 | 5 |
| core/conditionvariable | 4 | 0 | 0 | 0 | 0 | 4 |
| core/builtin_constants | 1 | 0 | 0 | 0 | 0 | 1 |
| core/fiber | 11 | 1 | 0 | 1 | 0 | 13 |
| core/dir | 32 | 0 | 0 | 2 | 0 | 34 |
| core/file | 59 | 7 | 0 | 2 | 0 | 68 |
| core/time | 58 | 5 | 0 | 3 | 0 | 66 |
| core/io | 77 | 3 | 0 | 1 | 0 | 81 |
| library/date | 60 | 0 | 0 | 38 | 0 | 98 |
| library/etc | 12 | 0 | 0 | 7 | 0 | 19 |
| library/pathname | 18 | 0 | 0 | 2 | 0 | 20 |
| library/stringio | 61 | 1 | 0 | 2 | 0 | 64 |
| library/cgi | 8 | 0 | 0 | 7 | 0 | 15 |
| library/tempfile | 6 | 3 | 0 | 1 | 0 | 10 |
| library/readline | 0 | 0 | 0 | 12 | 0 | 12 |
| library/yaml | 8 | 1 | 0 | 0 | 0 | 9 |
| library/zlib | 5 | 2 | 0 | 1 | 0 | 8 |
| library/monitor | 6 | 0 | 0 | 0 | 0 | 6 |
| library/securerandom | 5 | 0 | 0 | 0 | 0 | 5 |
| library/time | 6 | 0 | 0 | 0 | 0 | 6 |
| library/expect | 0 | 0 | 1 | 0 | 0 | 1 |
| library/base64 | 6 | 0 | 0 | 0 | 0 | 6 |
| library/shellwords | 1 | 0 | 0 | 0 | 0 | 1 |
| library/observer | 5 | 0 | 0 | 0 | 0 | 5 |
| core/array/pack | 26 | 0 | 0 | 1 | 0 | 27 |
| core/encoding/converter | 15 | 0 | 0 | 1 | 0 | 16 |
| core/encoding/invalid_byte_sequence_error | 7 | 0 | 0 | 0 | 0 | 7 |
| core/encoding/undefined_conversion_error | 5 | 0 | 0 | 0 | 0 | 5 |
| core/enumerator/arithmetic_sequence | 12 | 0 | 0 | 0 | 0 | 12 |
| core/enumerator/chain | 5 | 0 | 0 | 0 | 0 | 5 |
| core/enumerator/lazy | 29 | 0 | 0 | 0 | 1 | 30 |
| core/enumerator/product | 6 | 0 | 0 | 0 | 0 | 6 |
| core/file/constants | 1 | 0 | 0 | 0 | 0 | 1 |
| core/file/stat | 38 | 2 | 0 | 3 | 0 | 43 |
| core/gc/profiler | 5 | 0 | 0 | 2 | 0 | 7 |
| core/io/buffer | 19 | 2 | 0 | 1 | 0 | 22 |
| core/marshal | 4 | 2 | 0 | 0 | 0 | 6 |
| core/objectspace/weakkeymap | 7 | 0 | 0 | 0 | 0 | 7 |
| core/objectspace/weakmap | 15 | 0 | 0 | 0 | 0 | 15 |
| core/process | 28 | 11 | 0 | 1 | 0 | 40 |
| core/process/gid | 0 | 0 | 0 | 8 | 0 | 8 |
| core/process/status | 7 | 1 | 0 | 9 | 0 | 17 |
| core/process/sys | 0 | 0 | 0 | 15 | 0 | 15 |
| core/process/tms | 4 | 0 | 0 | 0 | 0 | 4 |
| core/process/uid | 0 | 0 | 0 | 8 | 0 | 8 |
| core/ruby/source_range | 0 | 0 | 0 | 1 | 0 | 1 |
| core/set/enumerable | 1 | 0 | 0 | 0 | 0 | 1 |
| core/set/sortedset | 0 | 0 | 0 | 1 | 0 | 1 |
| core/string/unpack | 24 | 0 | 0 | 2 | 0 | 26 |
| core/string/valid_encoding | 1 | 0 | 0 | 0 | 0 | 1 |
| core/thread | 34 | 8 | 1 | 2 | 0 | 45 |
| core/thread/backtrace | 1 | 0 | 0 | 0 | 0 | 1 |
| core/thread/backtrace/location | 5 | 2 | 0 | 0 | 0 | 7 |
| core/tracepoint | 12 | 7 | 0 | 0 | 0 | 19 |
| language/predefined | 2 | 0 | 0 | 0 | 0 | 2 |
| language/regexp | 8 | 3 | 0 | 0 | 0 | 11 |
| library/cgi/cookie | 0 | 0 | 0 | 9 | 0 | 9 |
| library/cgi/htmlextension | 0 | 0 | 0 | 26 | 0 | 26 |
| library/cgi/queryextension | 0 | 0 | 0 | 38 | 0 | 38 |
| library/date/format/bag | 0 | 0 | 0 | 2 | 0 | 2 |
| library/date/infinity | 0 | 0 | 0 | 10 | 0 | 10 |
| library/date/time | 1 | 0 | 0 | 0 | 0 | 1 |
| library/datetime | 20 | 0 | 0 | 15 | 0 | 35 |
| library/datetime/time | 1 | 0 | 0 | 0 | 0 | 1 |
| library/delegate/delegate_class | 6 | 0 | 0 | 0 | 0 | 6 |
| library/delegate/delegator | 18 | 0 | 0 | 0 | 0 | 18 |
| library/digest/instance | 3 | 0 | 0 | 0 | 0 | 3 |
| library/digest/md5 | 15 | 0 | 0 | 0 | 0 | 15 |
| library/digest/sha1 | 2 | 0 | 0 | 0 | 0 | 2 |
| library/digest/sha2 | 1 | 0 | 0 | 0 | 0 | 1 |
| library/digest/sha256 | 15 | 0 | 0 | 0 | 0 | 15 |
| library/digest/sha384 | 15 | 0 | 0 | 0 | 0 | 15 |
| library/digest/sha512 | 15 | 0 | 0 | 0 | 0 | 15 |
| library/English | 2 | 0 | 0 | 0 | 0 | 2 |
| library/io-wait | 3 | 0 | 0 | 0 | 0 | 3 |
| library/irb | 0 | 1 | 0 | 0 | 0 | 1 |
| library/logger/device | 3 | 0 | 0 | 0 | 0 | 3 |
| library/logger/logger | 9 | 1 | 0 | 0 | 0 | 10 |
| library/mkmf | 0 | 1 | 0 | 0 | 0 | 1 |
| library/openssl | 3 | 0 | 0 | 0 | 0 | 3 |
| library/openssl/digest | 8 | 0 | 0 | 0 | 0 | 8 |
| library/openssl/hmac | 2 | 0 | 0 | 0 | 0 | 2 |
| library/openssl/kdf | 0 | 1 | 1 | 0 | 0 | 2 |
| library/openssl/random | 2 | 0 | 0 | 0 | 0 | 2 |
| library/openssl/x509/name | 0 | 1 | 0 | 0 | 0 | 1 |
| library/openssl/x509/store | 0 | 1 | 0 | 0 | 0 | 1 |
| library/rbconfig | 2 | 1 | 0 | 0 | 0 | 3 |
| library/readline/history | 0 | 0 | 0 | 13 | 0 | 13 |
| library/singleton | 7 | 0 | 0 | 0 | 0 | 7 |
| library/socket/addrinfo | 46 | 0 | 0 | 2 | 0 | 48 |
| library/socket/ancillarydata | 11 | 0 | 0 | 1 | 0 | 12 |
| library/socket/constants | 1 | 0 | 0 | 0 | 0 | 1 |
| library/socket/ipsocket | 4 | 1 | 0 | 0 | 0 | 5 |
| library/socket/option | 6 | 0 | 0 | 0 | 0 | 6 |
| library/stringscanner | 44 | 0 | 0 | 0 | 0 | 44 |
| library/thread | 2 | 0 | 0 | 0 | 0 | 2 |
| library/tmpdir/dir | 1 | 1 | 0 | 0 | 0 | 2 |
| library/win32ole/win32ole | 0 | 0 | 0 | 18 | 0 | 18 |
| library/win32ole/win32ole_event | 0 | 0 | 0 | 2 | 0 | 2 |
| library/zlib/deflate | 1 | 2 | 0 | 0 | 0 | 3 |
| library/zlib/gzipfile | 3 | 1 | 0 | 0 | 0 | 4 |
| library/zlib/gzipreader | 14 | 1 | 0 | 0 | 0 | 15 |
| library/zlib/gzipwriter | 2 | 0 | 0 | 0 | 1 | 3 |
| library/zlib/inflate | 4 | 0 | 0 | 0 | 0 | 4 |
| library/zlib/zstream | 5 | 0 | 0 | 0 | 0 | 5 |
| library/digest | 2 | 0 | 0 | 0 | 0 | 2 |
| command_line | 28 | 4 | 0 | 0 | 0 | 32 |

_Generated by `mspec/scoreboard.sh`; re-run to refresh._

_Measured against ruby/spec `ruby@84a27934cf53`._
