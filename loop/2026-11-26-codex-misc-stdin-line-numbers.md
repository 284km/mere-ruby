# A2: standard input line numbers

Start from current main f4303e14. Before implementation, an unchanged
semantic probe against clean Ruby 4.0.10 confirms both engines lack
STDIN.lineno and lineno=. This breaks error_highlight ATTRASGN_3 before
its intended conversion error can be raised.

| Cause | Main, evaluator and VM | Ruby 4.0.10 |
| --- | --- | --- |
| Native standard input bypasses IO line state | NoMethodError for both readers | Per-stream count, C-int conversion, original assignment return value. |

Preserve closed/readability checks before conversion, independent ARGF and
stream counters, and real exception metadata. Reference io.c increments
ARGF's counter when reading its current input; direct reads otherwise put
the stream counter in $. The ARGF wrapper must retain its pre-read count.
Validate original IO, ARGF and error_highlight selections, both corpus
engines, gates and tight-GC fixed-seed RSS before publication.

## Completed focused acceptance

Corpus 1126 now runs three isolated stdin children without an Open3
prerequisite. All 22 output rows, stderr and status match clean Ruby on
both engines. Controls include Float assignment's original return value,
separate stream/ARGF counters, manually assigned $., closed/unreadable
priority, C-int bounds, per-yield counters, readlines, custom separators,
EOF stability, and object coercion's original return value.

Ordinary O2 SHA-256:
`216425c99326b4b7c479725409a3fb4d908d8db35a4f898c1266ca6b427e4556`.
The unchanged related CRuby files were checked one at a time against
reference, matching main f4303e14 and both candidate engines. Seed 1,
MERE_RUBY_GC_TIGHT=1, /usr/bin/time -l maximum RSS bytes:

| Original file | Phase | Engine | Max RSS | Outcome |
| --- | --- | --- | ---: | --- |
| `error_highlight/test_error_highlight.rb` | ref | evaluator | 33046528 | 1 tests, 8 assertions, 0 failures, 0 errors, 0 skips |
| `error_highlight/test_error_highlight.rb` | main | evaluator | 242958336 | 1 tests, 2 assertions, 1 failures, 0 errors, 0 skips |
| `error_highlight/test_error_highlight.rb` | main | VM | 249856000 | 1 tests, 2 assertions, 1 failures, 0 errors, 0 skips |
| `error_highlight/test_error_highlight.rb` | candidate | evaluator | 304103424 | 1 tests, 8 assertions, 0 failures, 0 errors, 0 skips |
| `error_highlight/test_error_highlight.rb` | candidate | VM | 319209472 | 1 tests, 8 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_io.rb` | ref | evaluator | 27607040 | 3 tests, 24 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_io.rb` | main | evaluator | 197869568 | 3 tests, 24 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_io.rb` | main | VM | 233144320 | 3 tests, 24 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_io.rb` | candidate | evaluator | 197771264 | 3 tests, 24 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_io.rb` | candidate | VM | 231456768 | 3 tests, 24 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_argf.rb` | ref | evaluator | 23494656 | 1 tests, 26 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_argf.rb` | main | evaluator | 175095808 | 1 tests, 26 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_argf.rb` | main | VM | 176226304 | 1 tests, 26 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_argf.rb` | candidate | evaluator | 174555136 | 1 tests, 26 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_argf.rb` | candidate | VM | 178356224 | 1 tests, 26 assertions, 0 failures, 0 errors, 0 skips |

ErrorHighlight selects args_ATTRASGN_3; IO selects set_lineno, set_lineno_gets
and set_lineno_readline; ARGF selects test_lineno. All candidate/reference
selections pass; main fails the original missing-STDIN-setter highlight.
Both full evaluator/VM corpus sweeps pass 965/965 programs with the hash
index ON/OFF, exit 0, using the immutable O2 binary recorded above.
Eight source gates, generated-C bracket depth, full/explicit completed
record hygiene and staged/unstaged whitespace checks pass.
No whole unit suite, Rails component suite, reference gem installation or
workflow change. The earlier Open3 fixture failure was a harness dependency,
not an accepted comparison; the final fixture uses existing popen/file APIs.
