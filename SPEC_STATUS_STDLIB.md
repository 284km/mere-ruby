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

⚠ **This is the second record.** These groups are swept with the reference's stdlib and
bundled gems on RUBYLIB (`SPEC_WITH_STDLIB=1 mspec/scoreboard.sh`): pure-Ruby libraries
that mere-ruby does not compile in, run from CRuby's own source. SPEC_STATUS.md, without
them, is what ships; the two are not added together.
| group | MATCH | DIFF | CRASH | SKIP | SLOW | total |
|---|---|---|---|---|---|---|
| library/uri/generic | 2 | 0 | 0 | 42 | 0 | 44 |
| library/bigdecimal | 0 | 0 | 57 | 0 | 0 | 57 |
| library/win32ole/win32ole_type | 0 | 0 | 0 | 19 | 0 | 19 |
| library/matrix | 64 | 4 | 0 | 2 | 0 | 70 |
| library/open3 | 1 | 0 | 0 | 10 | 0 | 11 |
| library/syslog | 0 | 0 | 20 | 0 | 0 | 20 |
| library/matrix/scalar | 0 | 0 | 0 | 9 | 0 | 9 |
| library/net-http/http | 50 | 0 | 0 | 7 | 0 | 57 |
| library/net-ftp | 53 | 1 | 0 | 2 | 0 | 56 |
| library/socket/unixserver | 0 | 8 | 0 | 0 | 0 | 8 |
| library/openstruct | 10 | 3 | 0 | 0 | 0 | 13 |
| library/net-http | 7 | 0 | 0 | 0 | 0 | 7 |
| library/getoptlong | 10 | 0 | 0 | 0 | 0 | 10 |
| library/matrix/vector | 5 | 0 | 0 | 0 | 0 | 5 |
| library/csv/ioreader | 0 | 0 | 0 | 4 | 0 | 4 |
| library/uri/parser | 3 | 0 | 0 | 5 | 0 | 8 |
| library/net-http/httpheader | 32 | 1 | 0 | 1 | 0 | 34 |
| library/ripper | 0 | 0 | 2 | 0 | 0 | 2 |
| library/csv/cell | 0 | 0 | 0 | 2 | 0 | 2 |
| library/net-http/httpresponse | 20 | 0 | 0 | 0 | 0 | 20 |
| library/fiddle/handle | 0 | 0 | 1 | 0 | 0 | 1 |
| library/prime | 7 | 0 | 0 | 0 | 0 | 7 |
| library/ipaddr | 6 | 0 | 0 | 0 | 0 | 6 |
| library/prime/integer | 4 | 0 | 0 | 0 | 0 | 4 |
| library/uri/ldap | 0 | 0 | 0 | 12 | 0 | 12 |
| library/socket/basicsocket | 7 | 16 | 0 | 1 | 0 | 24 |
| library/uri | 14 | 0 | 0 | 5 | 0 | 19 |
| library/timeout | 2 | 0 | 0 | 0 | 0 | 2 |
| library/find | 2 | 0 | 0 | 0 | 0 | 2 |
| library/net-http/httprequest | 1 | 0 | 0 | 0 | 0 | 1 |
| library/socket/unixsocket | 2 | 13 | 0 | 0 | 0 | 15 |
| library/socket/udpsocket | 5 | 5 | 0 | 0 | 0 | 10 |
| library/socket/tcpsocket | 7 | 2 | 0 | 0 | 0 | 9 |
| library/win32ole/win32ole_variable | 0 | 0 | 0 | 8 | 0 | 8 |
| library/uri/mailto | 1 | 0 | 0 | 7 | 0 | 8 |
| library/net-http/httpgenericrequest | 10 | 0 | 0 | 0 | 0 | 10 |
| library/uri/ftp | 2 | 0 | 0 | 5 | 0 | 7 |
| library/objectspace | 2 | 5 | 0 | 0 | 0 | 7 |
| library/win32ole/win32ole_param | 0 | 0 | 0 | 8 | 0 | 8 |
| library/csv/writer | 0 | 0 | 0 | 7 | 0 | 7 |
| library/uri/escape | 0 | 0 | 0 | 4 | 0 | 4 |
| library/csv/basicwriter | 0 | 0 | 0 | 3 | 0 | 3 |
| library/socket/tcpserver | 6 | 1 | 0 | 0 | 0 | 7 |
| library/optionparser | 2 | 0 | 0 | 0 | 0 | 2 |
| library/random/formatter | 1 | 0 | 0 | 0 | 0 | 1 |
| library/drb | 0 | 0 | 0 | 1 | 0 | 1 |
| library/matrix/eigenvalue_decomposition | 6 | 0 | 0 | 0 | 0 | 6 |
| library/resolv | 0 | 4 | 0 | 0 | 0 | 4 |
| library/uri/http | 1 | 0 | 0 | 1 | 0 | 2 |
| library/net-http/httpexceptions | 2 | 0 | 0 | 0 | 0 | 2 |
| library/pp | 1 | 0 | 0 | 0 | 0 | 1 |
| library/abbrev | 1 | 0 | 0 | 0 | 0 | 1 |
| library/weakref | 2 | 3 | 0 | 0 | 0 | 5 |
| library/erb/util | 3 | 1 | 0 | 0 | 0 | 4 |
| library/rubygems/gem | 1 | 1 | 0 | 0 | 0 | 2 |
| library/csv/stringreader | 0 | 0 | 0 | 2 | 0 | 2 |
| library/logger | 1 | 0 | 0 | 0 | 0 | 1 |
| library/socket/socket | 24 | 17 | 0 | 0 | 2 | 43 |
| library/win32ole/win32ole_method | 0 | 0 | 0 | 19 | 0 | 19 |
| library/csv/streambuf | 0 | 0 | 0 | 11 | 0 | 11 |
| library/csv | 5 | 0 | 0 | 4 | 0 | 9 |
| library/erb | 5 | 3 | 0 | 0 | 0 | 8 |
| library/matrix/lup_decomposition | 7 | 0 | 0 | 0 | 0 | 7 |
| library/coverage | 0 | 0 | 5 | 0 | 0 | 5 |
| library/csv/iobuf | 0 | 0 | 0 | 4 | 0 | 4 |
| library/rbconfig/sizeof | 2 | 0 | 0 | 0 | 0 | 2 |
| library/uri/util | 0 | 0 | 0 | 1 | 0 | 1 |
| library/erb/defmethod | 1 | 0 | 0 | 0 | 0 | 1 |

_Generated by `mspec/scoreboard.sh`; re-run to refresh._

_Measured against ruby/spec `ruby@84a27934cf53`._
