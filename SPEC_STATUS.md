# mere-ruby — ruby/spec status

Byte-exact conformance against ruby/spec (the de-facto Ruby suite), swept by
`mspec/scoreboard.sh`. Not a pass/fail gate — a checked-in record of where
mere-ruby matches CRuby and where it does not, like the other alternative
implementations' tags files. Per-file DIFF/CRASH lists live in `mspec/tags/`.

- **MATCH** identical output under mere-ruby and ruby
- **DIFF** runs on both, output differs (fidelity gap — often an error message or a frozen check)
- **CRASH** mere-ruby aborts where ruby does not (missing feature)
- **SKIP** ruby itself does not run it here (mock/subprocess/platform — unmeasurable)
- **SLOW** ran past this harness's per-file limit — working, not aborting

Measured against **ruby 4.0.6** (tools/ref_ruby.sh). The reference is part
of the subject: a row measured against another release is not comparable with the
ones around it, and the difference reads as movement in mere-ruby.
| group | MATCH | DIFF | CRASH | SKIP | SLOW | total |
|---|---|---|---|---|---|---|
| language | 47 | 20 | 0 | 0 | 0 | 67 |
| core/string | 113 | 1 | 0 | 0 | 0 | 114 |
| core/array | 102 | 2 | 0 | 0 | 1 | 105 |
| core/hash | 68 | 1 | 0 | 0 | 0 | 69 |
| core/range | 31 | 4 | 0 | 0 | 0 | 35 |
| core/comparable | 7 | 0 | 0 | 0 | 0 | 7 |
| core/complex | 43 | 0 | 0 | 0 | 0 | 43 |
| core/env | 45 | 0 | 0 | 0 | 0 | 45 |
| core/exception | 33 | 6 | 0 | 0 | 0 | 39 |
| core/false | 9 | 0 | 0 | 0 | 0 | 9 |
| core/float | 49 | 1 | 0 | 0 | 0 | 50 |
| core/integer | 68 | 2 | 0 | 0 | 0 | 70 |
| core/kernel | 90 | 27 | 0 | 1 | 0 | 118 |
| core/matchdata | 30 | 0 | 0 | 0 | 0 | 30 |
| core/method | 20 | 6 | 0 | 0 | 0 | 26 |
| core/mutex | 3 | 4 | 0 | 0 | 0 | 7 |
| core/nil | 18 | 0 | 0 | 0 | 0 | 18 |
| core/numeric | 45 | 1 | 0 | 0 | 0 | 46 |
| core/queue | 15 | 0 | 0 | 0 | 0 | 15 |
| core/rational | 31 | 1 | 0 | 0 | 0 | 32 |
| core/sizedqueue | 16 | 0 | 0 | 0 | 0 | 16 |
| core/struct | 26 | 4 | 0 | 0 | 0 | 30 |
| core/symbol | 27 | 2 | 0 | 0 | 0 | 29 |
| core/threadgroup | 5 | 0 | 0 | 0 | 0 | 5 |
| core/true | 9 | 0 | 0 | 0 | 0 | 9 |
| core/unboundmethod | 18 | 2 | 0 | 0 | 0 | 20 |
| core/systemexit | 2 | 0 | 0 | 0 | 0 | 2 |
| core/proc | 19 | 6 | 0 | 0 | 0 | 25 |
| core/set | 55 | 0 | 0 | 0 | 0 | 55 |
| core/regexp | 20 | 4 | 0 | 0 | 0 | 24 |
| core/enumerable | 57 | 4 | 0 | 0 | 0 | 61 |
| core/module | 42 | 41 | 0 | 1 | 1 | 85 |
| core/filetest | 23 | 2 | 0 | 0 | 0 | 25 |
| core/data | 8 | 5 | 0 | 0 | 0 | 13 |
| core/math | 24 | 5 | 0 | 0 | 0 | 29 |
| core/basicobject | 6 | 8 | 0 | 0 | 0 | 14 |
| core/argf | 25 | 10 | 0 | 0 | 0 | 35 |
| core/class | 2 | 6 | 0 | 0 | 0 | 8 |
| core/encoding | 9 | 8 | 0 | 0 | 0 | 17 |
| core/enumerator | 10 | 9 | 0 | 0 | 1 | 20 |
| core/random | 5 | 5 | 0 | 0 | 0 | 10 |
| core/signal | 2 | 1 | 0 | 0 | 0 | 3 |
| core/objectspace | 2 | 5 | 0 | 0 | 0 | 7 |
| core/main | 1 | 6 | 0 | 0 | 0 | 7 |
| core/gc | 1 | 10 | 0 | 0 | 0 | 11 |
| core/binding | 2 | 10 | 0 | 0 | 0 | 12 |
| core/refinement | 1 | 7 | 0 | 0 | 0 | 8 |
| core/warning | 1 | 4 | 0 | 0 | 0 | 5 |
| core/conditionvariable | 0 | 3 | 0 | 0 | 1 | 4 |
| core/builtin_constants | 1 | 0 | 0 | 0 | 0 | 1 |
| core/fiber | 1 | 12 | 0 | 0 | 0 | 13 |
| core/dir | 15 | 18 | 0 | 0 | 1 | 34 |
| core/file | 31 | 33 | 0 | 4 | 0 | 68 |
| core/time | 40 | 26 | 0 | 0 | 0 | 66 |
| core/io | 45 | 35 | 0 | 1 | 0 | 81 |
| library/date | 60 | 38 | 0 | 0 | 0 | 98 |
| library/etc | 16 | 3 | 0 | 0 | 0 | 19 |
| library/pathname | 13 | 7 | 0 | 0 | 0 | 20 |
| library/stringio | 33 | 28 | 0 | 1 | 2 | 64 |
| library/cgi | 11 | 4 | 0 | 0 | 0 | 15 |
| library/tempfile | 6 | 4 | 0 | 0 | 0 | 10 |
| library/readline | 4 | 0 | 0 | 8 | 0 | 12 |
| library/yaml | 3 | 6 | 0 | 0 | 0 | 9 |
| library/zlib | 3 | 5 | 0 | 0 | 0 | 8 |
| library/monitor | 2 | 4 | 0 | 0 | 0 | 6 |
| library/securerandom | 1 | 4 | 0 | 0 | 0 | 5 |
| library/time | 2 | 4 | 0 | 0 | 0 | 6 |
| library/expect | 1 | 0 | 0 | 0 | 0 | 1 |
| library/base64 | 3 | 3 | 0 | 0 | 0 | 6 |
| library/shellwords | 1 | 0 | 0 | 0 | 0 | 1 |
| library/observer | 5 | 0 | 0 | 0 | 0 | 5 |
| core/array/pack | 7 | 14 | 0 | 6 | 0 | 27 |
| core/encoding/converter | 1 | 15 | 0 | 0 | 0 | 16 |
| core/encoding/invalid_byte_sequence_error | 0 | 7 | 0 | 0 | 0 | 7 |
| core/encoding/undefined_conversion_error | 0 | 5 | 0 | 0 | 0 | 5 |
| core/enumerator/arithmetic_sequence | 10 | 2 | 0 | 0 | 0 | 12 |
| core/enumerator/chain | 1 | 4 | 0 | 0 | 0 | 5 |
| core/enumerator/lazy | 14 | 15 | 0 | 0 | 1 | 30 |
| core/enumerator/product | 1 | 5 | 0 | 0 | 0 | 6 |
| core/file/constants | 1 | 0 | 0 | 0 | 0 | 1 |
| core/file/stat | 29 | 14 | 0 | 0 | 0 | 43 |
| core/gc/profiler | 2 | 5 | 0 | 0 | 0 | 7 |
| core/io/buffer | 1 | 21 | 0 | 0 | 0 | 22 |
| core/marshal | 4 | 2 | 0 | 0 | 0 | 6 |
| core/objectspace/weakkeymap | 2 | 5 | 0 | 0 | 0 | 7 |
| core/objectspace/weakmap | 11 | 4 | 0 | 0 | 0 | 15 |
| core/process | 21 | 16 | 0 | 3 | 0 | 40 |
| core/process/gid | 8 | 0 | 0 | 0 | 0 | 8 |
| core/process/status | 10 | 6 | 0 | 1 | 0 | 17 |
| core/process/sys | 15 | 0 | 0 | 0 | 0 | 15 |
| core/process/tms | 0 | 4 | 0 | 0 | 0 | 4 |
| core/process/uid | 8 | 0 | 0 | 0 | 0 | 8 |
| core/ruby/source_range | 1 | 0 | 0 | 0 | 0 | 1 |
| core/set/enumerable | 1 | 0 | 0 | 0 | 0 | 1 |
| core/set/sortedset | 1 | 0 | 0 | 0 | 0 | 1 |
| core/string/unpack | 9 | 11 | 0 | 6 | 0 | 26 |
| core/string/valid_encoding | 1 | 0 | 0 | 0 | 0 | 1 |
| core/thread | 13 | 31 | 0 | 0 | 1 | 45 |
| core/thread/backtrace | 0 | 1 | 0 | 0 | 0 | 1 |
| core/thread/backtrace/location | 2 | 5 | 0 | 0 | 0 | 7 |
| core/tracepoint | 3 | 16 | 0 | 0 | 0 | 19 |
| language/predefined | 2 | 0 | 0 | 0 | 0 | 2 |
| language/regexp | 3 | 8 | 0 | 0 | 0 | 11 |

_Generated by `mspec/scoreboard.sh`; re-run to refresh._

_Measured against ruby/spec `ruby@84a27934cf53`._
