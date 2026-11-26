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

The O2 compiler/mgz pins are unchanged. The completed current-integration
acceptance below supersedes the earlier queued sweeps. No full unit suite
or Rails component suite was run; no new workflow changes.


## Current-main integration

The integration with main fd5f54b0 preserves fresh identities after removed
constants outside boxes, while every newly defined box-owned class remains
independent. Corpus 1112 and the expanded 1057 outside-box controls match
stdout, stderr and status on both engines. Earlier 884/884 sweeps apply to
the earlier head; fresh ordinary O2 r6 results are:

- sh run_corpus.sh --both: 949/949, hash index ON/OFF, exit 0.
- MERE_RUBY_VM=1 sh run_corpus.sh --both: 949/949, ON/OFF, exit 0.
- All eight source gates and full/explicit record_hygiene: pass.
- Generated-C bracket depth: 155 required / 1024 supplied, pass.
- Staged/unstaged diff whitespace checks: pass.

The exact binary SHA-256 is
e97a2cc29797e4c19c2e0b022896cc621146cdfbb392bc760506d7881c8c739f.
Clean Ruby 4.0.10 is selected through tools/ref_ruby.sh; compiler 9dec2ff6
and mgz 661a01d8, matching the main fd5f54b0 control build.

Unchanged ruby/test_box.rb selections add_constants_in_box,
eval_with_constants, eval_with_classes and very_basic_method_calls_and_constants
pass 4 tests / 53 assertions on reference and both candidate engines.
Main completes only 8 assertions and errors at Timeout::State::GET_TIME
in both engines; the corrected box lexical scope removes that error too.
RSS therefore includes substantially more completed work in the candidate
and is not a matched-workload heap-growth comparison. All invocations use
MERE_RUBY_GC_TIGHT=1, fixed --seed=1, one file at a time. Max RSS bytes:

| Engine | Main | Candidate |
| --- | ---: | ---: |
| Evaluator | 251674624 | 284033024 |
| VM | 255967232 | 279822336 |

The completed record is committed with the code integration in one push.
No reference gems, full unit/Rails suite or new workflow behavior. Main
commits newer than this pinned integration are not claimed runtime tested.
