# B13: independent class namespaces in Ruby::Box

Branch codex-misc-box-isolation starts from main fdda9150. Clean Ruby
4.0.10 gives each box its own Example1112 class and nested constants;
main leaks the first box's class namespace into the second.

Every newly defined box-owned class or module now gets an independent
internal identity, including the first one with a display name. Nested
bodies enter their real lexical constant scope. Qualified class resolution
follows the actual box-local constant bindings, including the VM's include
path, instead of reconstructing a shared display-name key.

Corpus 1112 checks two boxes, same-named classes, aliases, absolute paths,
nested modules/constants, reopening, class names and identity, and a
three-level nested mixin. Both engines match the clean reference. The
fixture enables the real feature with RUBY_BOX=1 in its child process.
No constant-read wrappers or replacement test helper are used.

## Related unchanged upstream file

The four selected test_box.rb cases pass 53 assertions on reference and
both candidate engines. Main runs only 8 assertions before the existing
Timeout GET_TIME NameError; the corrected lexical scope also fixes that
error. RSS comparisons therefore include more completed work in candidate.

| File | Candidate result | Main evaluator RSS | Candidate evaluator RSS | Main VM RSS | Candidate VM RSS |
| --- | --- | ---: | ---: | ---: | ---: |
| ruby/test_box.rb | 4 tests, 53 assertions, 0 failures, 0 errors, 0 skips | 258359296 | 282214400 | 260243456 | 279232512 |

## Validation policy

The reference is the clean pinned Ruby 4.0.10. The unchanged upstream
files above run one file at a time, against main and both candidate engines,
with `--seed=1` and `MERE_RUBY_GC_TIGHT=1`. RSS is max resident bytes from
`/usr/bin/time -l`. No gems are installed into the reference.

The O2 binary uses compiler 9dec2ff6 and mgz 661a01d8. Full acceptance is
running sequentially: `sh run_corpus.sh --both`, followed by
`MERE_RUBY_VM=1 sh run_corpus.sh --both`. Each includes gc_roots,
dup_defs, dead_defs, meth_writes, name_spec, rx_caps, ns_names, name_len
and full record_hygiene. Generated C is checked with
`MR_C=mr.c sh tools/bracket_depth_check.sh`; this loop record is also
checked explicitly with record_hygiene. Focused passing cases are not a
substitute for those pending sweeps. No full unit suite or Rails component
suite was run; no workflow is changed.
