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
| group | MATCH | DIFF | CRASH | SKIP | SLOW | total |
|---|---|---|---|---|---|---|
| language | 48 | 19 | 0 | 0 | 0 | 67 |
| core/string | 114 | 0 | 0 | 0 | 0 | 114 |
| core/array | 103 | 1 | 0 | 0 | 1 | 105 |
| core/hash | 68 | 1 | 0 | 0 | 0 | 69 |
| core/range | 31 | 4 | 0 | 0 | 0 | 35 |
| core/comparable | 7 | 0 | 0 | 0 | 0 | 7 |
| core/complex | 43 | 0 | 0 | 0 | 0 | 43 |
| core/env | 45 | 0 | 0 | 0 | 0 | 45 |
| core/exception | 33 | 6 | 0 | 0 | 0 | 39 |
| core/false | 9 | 0 | 0 | 0 | 0 | 9 |
| core/float | 50 | 0 | 0 | 0 | 0 | 50 |
| core/integer | 69 | 1 | 0 | 0 | 0 | 70 |
| core/kernel | 95 | 22 | 0 | 1 | 0 | 118 |
| core/matchdata | 30 | 0 | 0 | 0 | 0 | 30 |
| core/method | 22 | 4 | 0 | 0 | 0 | 26 |
| core/mutex | 3 | 4 | 0 | 0 | 0 | 7 |
| core/nil | 18 | 0 | 0 | 0 | 0 | 18 |
| core/numeric | 45 | 1 | 0 | 0 | 0 | 46 |
| core/queue | 15 | 0 | 0 | 0 | 0 | 15 |
| core/rational | 32 | 0 | 0 | 0 | 0 | 32 |
| core/sizedqueue | 16 | 0 | 0 | 0 | 0 | 16 |
| core/struct | 27 | 3 | 0 | 0 | 0 | 30 |
| core/symbol | 27 | 2 | 0 | 0 | 0 | 29 |
| core/threadgroup | 5 | 0 | 0 | 0 | 0 | 5 |
| core/true | 9 | 0 | 0 | 0 | 0 | 9 |
| core/unboundmethod | 18 | 2 | 0 | 0 | 0 | 20 |
| core/systemexit | 2 | 0 | 0 | 0 | 0 | 2 |
| core/proc | 20 | 5 | 0 | 0 | 0 | 25 |
| core/set | 55 | 0 | 0 | 0 | 0 | 55 |
| core/regexp | 20 | 4 | 0 | 0 | 0 | 24 |
| core/enumerable | 59 | 2 | 0 | 0 | 0 | 61 |
| core/module | 55 | 28 | 0 | 1 | 1 | 85 |
| core/filetest | 25 | 0 | 0 | 0 | 0 | 25 |
| core/data | 11 | 2 | 0 | 0 | 0 | 13 |
| core/math | 29 | 0 | 0 | 0 | 0 | 29 |
| core/basicobject | 10 | 4 | 0 | 0 | 0 | 14 |
| core/argf | 33 | 2 | 0 | 0 | 0 | 35 |
| core/class | 2 | 6 | 0 | 0 | 0 | 8 |
| core/encoding | 9 | 8 | 0 | 0 | 0 | 17 |
| core/enumerator | 14 | 5 | 0 | 0 | 1 | 20 |
| core/random | 7 | 3 | 0 | 0 | 0 | 10 |
| core/signal | 3 | 0 | 0 | 0 | 0 | 3 |
| core/objectspace | 4 | 3 | 0 | 0 | 0 | 7 |
| core/main | 5 | 2 | 0 | 0 | 0 | 7 |
| core/gc | 9 | 2 | 0 | 0 | 0 | 11 |
| core/binding | 5 | 7 | 0 | 0 | 0 | 12 |
| core/refinement | 7 | 1 | 0 | 0 | 0 | 8 |
| core/warning | 3 | 2 | 0 | 0 | 0 | 5 |
| core/conditionvariable | 1 | 2 | 0 | 0 | 1 | 4 |
| core/builtin_constants | 1 | 0 | 0 | 0 | 0 | 1 |
| core/fiber | 2 | 11 | 0 | 0 | 0 | 13 |
| core/dir | 33 | 1 | 0 | 0 | 0 | 34 |
| core/file | 55 | 9 | 0 | 4 | 0 | 68 |
| core/time | 61 | 5 | 0 | 0 | 0 | 66 |
| core/io | 58 | 22 | 0 | 1 | 0 | 81 |
| library/date | 98 | 0 | 0 | 0 | 0 | 98 |
| library/etc | 17 | 2 | 0 | 0 | 0 | 19 |
| library/pathname | 18 | 2 | 0 | 0 | 0 | 20 |
| library/stringio | 61 | 2 | 0 | 1 | 0 | 64 |
| library/cgi | 14 | 1 | 0 | 0 | 0 | 15 |
| library/tempfile | 7 | 3 | 0 | 0 | 0 | 10 |
| library/readline | 4 | 0 | 0 | 8 | 0 | 12 |
| library/yaml | 9 | 0 | 0 | 0 | 0 | 9 |
| library/zlib | 6 | 2 | 0 | 0 | 0 | 8 |
| library/monitor | 3 | 3 | 0 | 0 | 0 | 6 |
| library/securerandom | 5 | 0 | 0 | 0 | 0 | 5 |
| library/time | 6 | 0 | 0 | 0 | 0 | 6 |
| library/expect | 1 | 0 | 0 | 0 | 0 | 1 |
| library/base64 | 6 | 0 | 0 | 0 | 0 | 6 |
| library/shellwords | 1 | 0 | 0 | 0 | 0 | 1 |
| library/observer | 5 | 0 | 0 | 0 | 0 | 5 |
| core/array/pack | 18 | 3 | 0 | 6 | 0 | 27 |
| core/encoding/converter | 15 | 1 | 0 | 0 | 0 | 16 |
| core/encoding/invalid_byte_sequence_error | 7 | 0 | 0 | 0 | 0 | 7 |
| core/encoding/undefined_conversion_error | 5 | 0 | 0 | 0 | 0 | 5 |
| core/enumerator/arithmetic_sequence | 12 | 0 | 0 | 0 | 0 | 12 |
| core/enumerator/chain | 4 | 1 | 0 | 0 | 0 | 5 |
| core/enumerator/lazy | 18 | 11 | 0 | 0 | 1 | 30 |
| core/enumerator/product | 6 | 0 | 0 | 0 | 0 | 6 |
| core/file/constants | 1 | 0 | 0 | 0 | 0 | 1 |
| core/file/stat | 40 | 3 | 0 | 0 | 0 | 43 |
| core/gc/profiler | 7 | 0 | 0 | 0 | 0 | 7 |
| core/io/buffer | 7 | 15 | 0 | 0 | 0 | 22 |
| core/marshal | 4 | 2 | 0 | 0 | 0 | 6 |
| core/objectspace/weakkeymap | 6 | 1 | 0 | 0 | 0 | 7 |
| core/objectspace/weakmap | 15 | 0 | 0 | 0 | 0 | 15 |
| core/process | 31 | 6 | 0 | 3 | 0 | 40 |
| core/process/gid | 8 | 0 | 0 | 0 | 0 | 8 |
| core/process/status | 11 | 5 | 0 | 1 | 0 | 17 |
| core/process/sys | 15 | 0 | 0 | 0 | 0 | 15 |
| core/process/tms | 4 | 0 | 0 | 0 | 0 | 4 |
| core/process/uid | 8 | 0 | 0 | 0 | 0 | 8 |
| core/ruby/source_range | 1 | 0 | 0 | 0 | 0 | 1 |
| core/set/enumerable | 1 | 0 | 0 | 0 | 0 | 1 |
| core/set/sortedset | 1 | 0 | 0 | 0 | 0 | 1 |
| core/string/unpack | 17 | 3 | 0 | 6 | 0 | 26 |
| core/string/valid_encoding | 1 | 0 | 0 | 0 | 0 | 1 |
| core/thread | 22 | 22 | 0 | 0 | 1 | 45 |
| core/thread/backtrace | 0 | 1 | 0 | 0 | 0 | 1 |
| core/thread/backtrace/location | 2 | 5 | 0 | 0 | 0 | 7 |
| core/tracepoint | 6 | 13 | 0 | 0 | 0 | 19 |
| language/predefined | 2 | 0 | 0 | 0 | 0 | 2 |
| language/regexp | 3 | 8 | 0 | 0 | 0 | 11 |
| library/cgi/cookie | 9 | 0 | 0 | 0 | 0 | 9 |
| library/cgi/htmlextension | 26 | 0 | 0 | 0 | 0 | 26 |
| library/cgi/queryextension | 38 | 0 | 0 | 0 | 0 | 38 |
| library/date/format/bag | 2 | 0 | 0 | 0 | 0 | 2 |
| library/date/infinity | 10 | 0 | 0 | 0 | 0 | 10 |
| library/date/time | 0 | 1 | 0 | 0 | 0 | 1 |
| library/datetime | 35 | 0 | 0 | 0 | 0 | 35 |
| library/datetime/time | 0 | 1 | 0 | 0 | 0 | 1 |
| library/delegate/delegate_class | 6 | 0 | 0 | 0 | 0 | 6 |
| library/delegate/delegator | 16 | 2 | 0 | 0 | 0 | 18 |
| library/digest/instance | 3 | 0 | 0 | 0 | 0 | 3 |
| library/digest/md5 | 15 | 0 | 0 | 0 | 0 | 15 |
| library/digest/sha1 | 2 | 0 | 0 | 0 | 0 | 2 |
| library/digest/sha2 | 1 | 0 | 0 | 0 | 0 | 1 |
| library/digest/sha256 | 15 | 0 | 0 | 0 | 0 | 15 |
| library/digest/sha384 | 15 | 0 | 0 | 0 | 0 | 15 |
| library/digest/sha512 | 15 | 0 | 0 | 0 | 0 | 15 |
| library/English | 1 | 1 | 0 | 0 | 0 | 2 |
| library/io-wait | 0 | 3 | 0 | 0 | 0 | 3 |
| library/irb | 0 | 1 | 0 | 0 | 0 | 1 |
| library/logger/device | 3 | 0 | 0 | 0 | 0 | 3 |
| library/logger/logger | 9 | 1 | 0 | 0 | 0 | 10 |
| library/mkmf | 1 | 0 | 0 | 0 | 0 | 1 |
| library/openssl | 1 | 2 | 0 | 0 | 0 | 3 |
| library/openssl/digest | 7 | 0 | 0 | 1 | 0 | 8 |
| library/openssl/hmac | 2 | 0 | 0 | 0 | 0 | 2 |
| library/openssl/kdf | 1 | 0 | 0 | 1 | 0 | 2 |
| library/openssl/random | 2 | 0 | 0 | 0 | 0 | 2 |
| library/openssl/x509/name | 0 | 1 | 0 | 0 | 0 | 1 |
| library/openssl/x509/store | 0 | 1 | 0 | 0 | 0 | 1 |
| library/rbconfig | 2 | 0 | 0 | 1 | 0 | 3 |
| library/readline/history | 0 | 0 | 0 | 13 | 0 | 13 |
| library/singleton | 7 | 0 | 0 | 0 | 0 | 7 |
| library/socket/addrinfo | 0 | 0 | 0 | 48 | 0 | 48 |
| library/socket/ancillarydata | 0 | 0 | 0 | 12 | 0 | 12 |
| library/socket/constants | 0 | 0 | 0 | 1 | 0 | 1 |
| library/socket/ipsocket | 0 | 0 | 0 | 5 | 0 | 5 |
| library/socket/option | 0 | 0 | 0 | 6 | 0 | 6 |
| library/stringscanner | 32 | 0 | 0 | 12 | 0 | 44 |
| library/thread | 2 | 0 | 0 | 0 | 0 | 2 |
| library/tmpdir/dir | 1 | 1 | 0 | 0 | 0 | 2 |
| library/win32ole/win32ole | 18 | 0 | 0 | 0 | 0 | 18 |
| library/win32ole/win32ole_event | 2 | 0 | 0 | 0 | 0 | 2 |
| library/zlib/deflate | 1 | 2 | 0 | 0 | 0 | 3 |
| library/zlib/gzipfile | 3 | 1 | 0 | 0 | 0 | 4 |
| library/zlib/gzipreader | 10 | 5 | 0 | 0 | 0 | 15 |
| library/zlib/gzipwriter | 1 | 1 | 0 | 0 | 1 | 3 |
| library/zlib/inflate | 0 | 4 | 0 | 0 | 0 | 4 |
| library/zlib/zstream | 4 | 1 | 0 | 0 | 0 | 5 |
| library/digest | 1 | 1 | 0 | 0 | 0 | 2 |

_Generated by `mspec/scoreboard.sh`; re-run to refresh._

_Measured against ruby/spec `ruby@84a27934cf53`._
