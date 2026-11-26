# Parser: preserve raw word-list escape boundaries

Branch base: main 2cc4b683. A2's unchanged ripper/test_scanner_events.rb
#test_gvar fails only on the evaluator: the expected percent-word list
joins the backslash element with its successor. Main 03694405 reproduces
that failure against clean Ruby 4.0.10; the VM passes the same case.

| Cause | Related unchanged test | Correction boundary |
| --- | --- | --- |
| Lowercase percent-word bodies unescape a doubled backslash before pw_word reads it again | ripper/test_scanner_events.rb test_gvar | Keep word-list escapes until word splitting; preserve ordinary percent strings. |

The raw body scanner is also used by percent q/s literals, so those must
retain their single unescape. Word lists must preserve doubled backslashes until the word scanner
consumes them.
Escaped non-whitespace delimiters still lose their quoting backslash once.
No token/source location is guessed and no Ripper token is fabricated.

Corpus 993 will compare raw/interpolated words and symbols across delimiters
and escape boundaries. Original ruby/test_parse.rb words/percent and
ruby/test_literal.rb symbol-array cases, plus the scanner case, will be
compared against main on both engines. Tight-GC fixed-seed max RSS, both
full corpus sweeps, gates and record hygiene remain pending. No full unit
or Rails component suite is run; no reference gems are installed.


## Matching-main acceptance

The candidate binary SHA-256 is
8092c024c3d315aef2c83616da5d4fdd3b29a9ec0c6a942a212c4863b781db79.
Compare with the ordinary O2 build of the exact branch base, main 2cc4b683,
SHA-256 f24e9338b327220feed404f10c82db1c0abf0a6d558fcf05f37675f12dbfed00.
Both use Mere 9dec2ff6 and mgz 661a01d8; reference selection is the clean
Ruby 4.0.10 through tools/ref_ruby.sh. Corpus 993 matches all 122 rows,
stderr and exit status on both engines. The main evaluator differs; its
VM already matches. These supersede older 03694405 control measurements.

Unchanged original files, one file at a time, --seed=1, tight GC:

| File / selection | Reference / candidate result | Main evaluator result | Main VM result |
| --- | --- | --- | --- |
| ripper/test_scanner_events.rb | 1 tests, 5 assertions, 0 failures, 0 errors, 0 skips | 1 tests, 5 assertions, 1 failures, 0 errors, 0 skips | 1 tests, 5 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_parse.rb | 2 tests, 16 assertions, 0 failures, 0 errors, 0 skips | 2 tests, 16 assertions, 0 failures, 0 errors, 0 skips | 2 tests, 16 assertions, 0 failures, 0 errors, 0 skips |
| ruby/test_literal.rb | 1 tests, 6 assertions, 0 failures, 0 errors, 0 skips | 1 tests, 6 assertions, 0 failures, 0 errors, 0 skips | 1 tests, 6 assertions, 0 failures, 0 errors, 0 skips |

Max RSS bytes from /usr/bin/time -l, MERE_RUBY_GC_TIGHT=1, fixed seed 1:

| File | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: |
| ripper/test_scanner_events.rb | 225853440 | 225804288 | 230375424 | 229097472 |
| ruby/test_parse.rb | 179191808 | 181256192 | 192069632 | 190889984 |
| ruby/test_literal.rb | 169279488 | 168460288 | 169803776 | 166346752 |

The eight source gates, generated-C bracket depth, full/explicit record
hygiene and diff whitespace checks pass. Both full corpus sweeps below have now completed on that same binary.

## Completed local acceptance

- `sh run_corpus.sh --both`: 961/961, hash index ON and OFF, exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: 961/961, ON and OFF, exit 0.
- All eight source gates, generated-C bracket depth, full and explicit
  record_hygiene, staged/unstaged whitespace checks: PASS.

The source correction, 122-row fixture and completed record are committed
and pushed together for review. No full unit/framework suite, workflow edit
or reference gem installation.
