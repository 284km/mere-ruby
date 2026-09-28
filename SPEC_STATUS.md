# mere-ruby — ruby/spec status

Byte-exact conformance against ruby/spec (the de-facto Ruby suite), swept by
`mspec/scoreboard.sh`. Not a pass/fail gate — a checked-in record of where
mere-ruby matches CRuby and where it does not, like the other alternative
implementations' tags files. Per-file DIFF/CRASH lists live in `mspec/tags/`.

- **MATCH** identical output under mere-ruby and ruby
- **DIFF** runs on both, output differs (fidelity gap — often an error message or a frozen check)
- **CRASH** mere-ruby aborts ON ITS OWN where ruby does not (missing feature)
- **SKIP** ruby itself does not run it here (mock/subprocess/platform — unmeasurable)
- **SLOW** stopped by one of this harness's bounds — CPU seconds, wall clock or bytes —
  and so working, not aborting. The row in `mspec/tags/` names which bound answered.

Measured against **ruby 4.0.6** (tools/ref_ruby.sh). The reference is part
of the subject: a row measured against another release is not comparable with the
ones around it, and the difference reads as movement in mere-ruby.

⚠ **The shim is part of the subject too.** From 2026-09-29 it runs what mspec runs:
shared examples (`it_behaves_like`, 1781 lines that used to run nothing), the
platform / version / feature guards, mspec's before/after order, and its raise
matcher (message, `cause:` and the block). A row from before that date compared
fewer examples, so MATCH 2589 then and 2221 now are not the same question: the
368 files are ones whose newly compared examples differ, not behaviour that was lost.
| group | MATCH | DIFF | CRASH | SKIP | SLOW | total |
|---|---|---|---|---|---|---|
| language | 38 | 29 | 0 | 0 | 0 | 67 |
| core/string | 87 | 26 | 0 | 0 | 1 | 114 |
| core/array | 90 | 13 | 0 | 0 | 2 | 105 |
| core/hash | 58 | 11 | 0 | 0 | 0 | 69 |
| core/range | 27 | 8 | 0 | 0 | 0 | 35 |
| core/comparable | 7 | 0 | 0 | 0 | 0 | 7 |
| core/complex | 43 | 0 | 0 | 0 | 0 | 43 |
| core/env | 42 | 3 | 0 | 0 | 0 | 45 |
| core/exception | 29 | 10 | 0 | 0 | 0 | 39 |
| core/false | 9 | 0 | 0 | 0 | 0 | 9 |
| core/float | 50 | 0 | 0 | 0 | 0 | 50 |
| core/integer | 68 | 0 | 0 | 0 | 2 | 70 |
| core/kernel | 81 | 33 | 2 | 0 | 2 | 118 |
| core/matchdata | 30 | 0 | 0 | 0 | 0 | 30 |
| core/method | 20 | 6 | 0 | 0 | 0 | 26 |
| core/mutex | 7 | 0 | 0 | 0 | 0 | 7 |
| core/nil | 18 | 0 | 0 | 0 | 0 | 18 |
| core/numeric | 45 | 0 | 0 | 0 | 1 | 46 |
| core/queue | 13 | 2 | 0 | 0 | 0 | 15 |
| core/rational | 32 | 0 | 0 | 0 | 0 | 32 |
| core/sizedqueue | 13 | 3 | 0 | 0 | 0 | 16 |
| core/struct | 21 | 9 | 0 | 0 | 0 | 30 |
| core/symbol | 24 | 5 | 0 | 0 | 0 | 29 |
| core/threadgroup | 5 | 0 | 0 | 0 | 0 | 5 |
| core/true | 9 | 0 | 0 | 0 | 0 | 9 |
| core/unboundmethod | 15 | 5 | 0 | 0 | 0 | 20 |
| core/systemexit | 2 | 0 | 0 | 0 | 0 | 2 |
| core/proc | 19 | 6 | 0 | 0 | 0 | 25 |
| core/set | 54 | 1 | 0 | 0 | 0 | 55 |
| core/regexp | 18 | 6 | 0 | 0 | 0 | 24 |
| core/enumerable | 38 | 22 | 0 | 0 | 1 | 61 |
| core/module | 53 | 31 | 0 | 0 | 1 | 85 |
| core/filetest | 10 | 15 | 0 | 0 | 0 | 25 |
| core/data | 11 | 2 | 0 | 0 | 0 | 13 |
| core/math | 28 | 1 | 0 | 0 | 0 | 29 |
| core/basicobject | 7 | 7 | 0 | 0 | 0 | 14 |
| core/argf | 30 | 5 | 0 | 0 | 0 | 35 |
| core/class | 4 | 4 | 0 | 0 | 0 | 8 |
| core/encoding | 15 | 2 | 0 | 0 | 0 | 17 |
| core/enumerator | 17 | 3 | 0 | 0 | 0 | 20 |
| core/random | 7 | 3 | 0 | 0 | 0 | 10 |
| core/signal | 1 | 2 | 0 | 0 | 0 | 3 |
| core/objectspace | 5 | 2 | 0 | 0 | 0 | 7 |
| core/main | 5 | 2 | 0 | 0 | 0 | 7 |
| core/gc | 9 | 2 | 0 | 0 | 0 | 11 |
| core/binding | 4 | 8 | 0 | 0 | 0 | 12 |
| core/refinement | 7 | 1 | 0 | 0 | 0 | 8 |
| core/warning | 3 | 2 | 0 | 0 | 0 | 5 |
| core/conditionvariable | 4 | 0 | 0 | 0 | 0 | 4 |
| core/builtin_constants | 1 | 0 | 0 | 0 | 0 | 1 |
| core/fiber | 12 | 1 | 0 | 0 | 0 | 13 |
| core/dir | 19 | 15 | 0 | 0 | 0 | 34 |
| core/file | 32 | 36 | 0 | 0 | 0 | 68 |
| core/time | 51 | 15 | 0 | 0 | 0 | 66 |
| core/io | 24 | 52 | 4 | 0 | 1 | 81 |
| library/date | 96 | 2 | 0 | 0 | 0 | 98 |
| library/etc | 7 | 11 | 1 | 0 | 0 | 19 |
| library/pathname | 17 | 3 | 0 | 0 | 0 | 20 |
| library/stringio | 58 | 6 | 0 | 0 | 0 | 64 |
| library/cgi | 14 | 1 | 0 | 0 | 0 | 15 |
| library/tempfile | 7 | 3 | 0 | 0 | 0 | 10 |
| library/readline | 12 | 0 | 0 | 0 | 0 | 12 |
| library/yaml | 7 | 2 | 0 | 0 | 0 | 9 |
| library/zlib | 5 | 3 | 0 | 0 | 0 | 8 |
| library/monitor | 6 | 0 | 0 | 0 | 0 | 6 |
| library/securerandom | 5 | 0 | 0 | 0 | 0 | 5 |
| library/time | 6 | 0 | 0 | 0 | 0 | 6 |
| library/expect | 0 | 0 | 1 | 0 | 0 | 1 |
| library/base64 | 6 | 0 | 0 | 0 | 0 | 6 |
| library/shellwords | 1 | 0 | 0 | 0 | 0 | 1 |
| library/observer | 5 | 0 | 0 | 0 | 0 | 5 |
| core/array/pack | 5 | 22 | 0 | 0 | 0 | 27 |
| core/encoding/converter | 15 | 1 | 0 | 0 | 0 | 16 |
| core/encoding/invalid_byte_sequence_error | 7 | 0 | 0 | 0 | 0 | 7 |
| core/encoding/undefined_conversion_error | 5 | 0 | 0 | 0 | 0 | 5 |
| core/enumerator/arithmetic_sequence | 12 | 0 | 0 | 0 | 0 | 12 |
| core/enumerator/chain | 4 | 1 | 0 | 0 | 0 | 5 |
| core/enumerator/lazy | 29 | 0 | 0 | 0 | 1 | 30 |
| core/enumerator/product | 6 | 0 | 0 | 0 | 0 | 6 |
| core/file/constants | 1 | 0 | 0 | 0 | 0 | 1 |
| core/file/stat | 22 | 21 | 0 | 0 | 0 | 43 |
| core/gc/profiler | 7 | 0 | 0 | 0 | 0 | 7 |
| core/io/buffer | 14 | 8 | 0 | 0 | 0 | 22 |
| core/marshal | 4 | 2 | 0 | 0 | 0 | 6 |
| core/objectspace/weakkeymap | 6 | 1 | 0 | 0 | 0 | 7 |
| core/objectspace/weakmap | 12 | 3 | 0 | 0 | 0 | 15 |
| core/process | 12 | 26 | 0 | 0 | 2 | 40 |
| core/process/gid | 8 | 0 | 0 | 0 | 0 | 8 |
| core/process/status | 10 | 7 | 0 | 0 | 0 | 17 |
| core/process/sys | 15 | 0 | 0 | 0 | 0 | 15 |
| core/process/tms | 4 | 0 | 0 | 0 | 0 | 4 |
| core/process/uid | 8 | 0 | 0 | 0 | 0 | 8 |
| core/ruby/source_range | 1 | 0 | 0 | 0 | 0 | 1 |
| core/set/enumerable | 1 | 0 | 0 | 0 | 0 | 1 |
| core/set/sortedset | 1 | 0 | 0 | 0 | 0 | 1 |
| core/string/unpack | 4 | 22 | 0 | 0 | 0 | 26 |
| core/string/valid_encoding | 1 | 0 | 0 | 0 | 0 | 1 |
| core/thread | 35 | 10 | 0 | 0 | 0 | 45 |
| core/thread/backtrace | 1 | 0 | 0 | 0 | 0 | 1 |
| core/thread/backtrace/location | 2 | 5 | 0 | 0 | 0 | 7 |
| core/tracepoint | 12 | 7 | 0 | 0 | 0 | 19 |
| language/predefined | 2 | 0 | 0 | 0 | 0 | 2 |
| language/regexp | 5 | 6 | 0 | 0 | 0 | 11 |
| library/cgi/cookie | 9 | 0 | 0 | 0 | 0 | 9 |
| library/cgi/htmlextension | 26 | 0 | 0 | 0 | 0 | 26 |
| library/cgi/queryextension | 38 | 0 | 0 | 0 | 0 | 38 |
| library/date/format/bag | 2 | 0 | 0 | 0 | 0 | 2 |
| library/date/infinity | 10 | 0 | 0 | 0 | 0 | 10 |
| library/date/time | 0 | 1 | 0 | 0 | 0 | 1 |
| library/datetime | 29 | 6 | 0 | 0 | 0 | 35 |
| library/datetime/time | 0 | 1 | 0 | 0 | 0 | 1 |
| library/delegate/delegate_class | 6 | 0 | 0 | 0 | 0 | 6 |
| library/delegate/delegator | 16 | 2 | 0 | 0 | 0 | 18 |
| library/digest/instance | 3 | 0 | 0 | 0 | 0 | 3 |
| library/digest/md5 | 14 | 1 | 0 | 0 | 0 | 15 |
| library/digest/sha1 | 1 | 1 | 0 | 0 | 0 | 2 |
| library/digest/sha2 | 1 | 0 | 0 | 0 | 0 | 1 |
| library/digest/sha256 | 14 | 1 | 0 | 0 | 0 | 15 |
| library/digest/sha384 | 14 | 1 | 0 | 0 | 0 | 15 |
| library/digest/sha512 | 14 | 1 | 0 | 0 | 0 | 15 |
| library/English | 2 | 0 | 0 | 0 | 0 | 2 |
| library/io-wait | 3 | 0 | 0 | 0 | 0 | 3 |
| library/irb | 0 | 1 | 0 | 0 | 0 | 1 |
| library/logger/device | 3 | 0 | 0 | 0 | 0 | 3 |
| library/logger/logger | 9 | 1 | 0 | 0 | 0 | 10 |
| library/mkmf | 0 | 1 | 0 | 0 | 0 | 1 |
| library/openssl | 1 | 2 | 0 | 0 | 0 | 3 |
| library/openssl/digest | 5 | 3 | 0 | 0 | 0 | 8 |
| library/openssl/hmac | 2 | 0 | 0 | 0 | 0 | 2 |
| library/openssl/kdf | 0 | 1 | 1 | 0 | 0 | 2 |
| library/openssl/random | 0 | 2 | 0 | 0 | 0 | 2 |
| library/openssl/x509/name | 0 | 1 | 0 | 0 | 0 | 1 |
| library/openssl/x509/store | 0 | 1 | 0 | 0 | 0 | 1 |
| library/rbconfig | 2 | 1 | 0 | 0 | 0 | 3 |
| library/readline/history | 13 | 0 | 0 | 0 | 0 | 13 |
| library/singleton | 7 | 0 | 0 | 0 | 0 | 7 |
| library/socket/addrinfo | 0 | 48 | 0 | 0 | 0 | 48 |
| library/socket/ancillarydata | 1 | 11 | 0 | 0 | 0 | 12 |
| library/socket/constants | 0 | 1 | 0 | 0 | 0 | 1 |
| library/socket/ipsocket | 0 | 5 | 0 | 0 | 0 | 5 |
| library/socket/option | 0 | 6 | 0 | 0 | 0 | 6 |
| library/stringscanner | 37 | 7 | 0 | 0 | 0 | 44 |
| library/thread | 2 | 0 | 0 | 0 | 0 | 2 |
| library/tmpdir/dir | 1 | 1 | 0 | 0 | 0 | 2 |
| library/win32ole/win32ole | 18 | 0 | 0 | 0 | 0 | 18 |
| library/win32ole/win32ole_event | 2 | 0 | 0 | 0 | 0 | 2 |
| library/zlib/deflate | 1 | 2 | 0 | 0 | 0 | 3 |
| library/zlib/gzipfile | 3 | 1 | 0 | 0 | 0 | 4 |
| library/zlib/gzipreader | 11 | 4 | 0 | 0 | 0 | 15 |
| library/zlib/gzipwriter | 2 | 0 | 0 | 0 | 1 | 3 |
| library/zlib/inflate | 0 | 4 | 0 | 0 | 0 | 4 |
| library/zlib/zstream | 4 | 1 | 0 | 0 | 0 | 5 |
| library/digest | 1 | 1 | 0 | 0 | 0 | 2 |

_Generated by `mspec/scoreboard.sh`; re-run to refresh._

_Measured against ruby/spec `ruby@84a27934cf53`._
