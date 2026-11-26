# The C API contracts on the ISeq VM

Before the VM becomes the default, C extensions have to be shown to work on
it. #284, #286 and #292 each recorded "capi_check on the VM stops at api.rb's
rb_errinfo contract" as a gap from before. This closes that gap and puts the
VM run in CI.

## What was found

- **`MERE_RUBY_VM=1 tools/capi_check.py` never ran the VM.** `run()` starts
  every run with the caller's `MERE_RUBY_*` variables removed (so a knob left
  in the shell cannot change a contract), and that took `MERE_RUBY_VM` too.
  The run passed, on the evaluator. Every "capi_check under the VM" number
  in earlier records was the evaluator's.
- Run on the VM by hand (the fixtures capi_check had built, each script with
  `MERE_RUBY_VM=1`), main 85da98fb:
  - ensure 58, typeddata 115, loader 49, numeric 13 and fiber 16 contracts pass;
  - api.rb stops at line 643, the first contract after the rb_protect ones:
    inside a Ruby `rescue`, a C method's `rb_errinfo()` must answer nil, and
    on the VM it answered the ArgumentError an earlier `rb_protect` had left.

## What changed

- **vm_checkmatch** (main.mere): a rescue clause that is taken
  (`checkmatch` of type 3 answering true) clears C's errinfo
  (`capi_errinfo_clear`), as the evaluator's `run_rescues` does when a clause
  matches, and as entering a rescue clears `ec->errinfo` in CRuby. A clause
  that does not match clears nothing, as on the evaluator. Without a C
  extension loaded this is one test of `mr_capi_booted`.
- **`capi_check.py --vm`**: every mere-ruby run (the contracts, stress, the
  six negative controls) gets `MERE_RUBY_VM=report`. A line of the report
  naming the contract script itself -- the VM did not take it, the evaluator
  ran it -- fails that run, and a negative control that "fails" that way does
  not count as failing. ("The native compiler declined" is not such a line:
  the Ruby compiler then compiles the script for the VM.) The summary says
  `mere-ruby (VM)`.
- **CI** runs capi_check twice on macOS and on Linux: as before, then with
  `--vm`.

## Checked

On this branch (main 85da98fb + the change), mere 9dec2ff6, reference ruby
4.0.10.

- `capi_check.py`: ensure 58, typeddata 115, loader 49 (48 on the reference
  plus mere-ruby's own one), numeric 13, fiber 16, api 405 -- both sides
  agree, the same under collection stress, and each of the six negative
  controls fails.
- `capi_check.py --vm`: the same counts with mere-ruby's side on the VM,
  under stress too, and the six negative controls fail with the same
  messages as on the evaluator (no-dmark at typeddata.rb:21, no-dfree
  "unreachable C cycles are reclaimed", no-ensure "normal cleanup once",
  no-switch "the calls in progress are out of step", no-fileprobe "one
  constructor, then Init", no-builtin at api.rb:35).
- The check sees a script the VM refuses: with `BEGIN { }` put at the top of
  numeric.rb for the run, `--vm` failed with "the VM did not take numeric.rb,
  the evaluator ran it" for the contracts and for stress, and
  "numeric: a side did not finish its contracts".
- Main's build, api.rb on the VM by hand: stops at line 643 (above). This
  build: 405 passed.
- `run_corpus.sh --both`: the gates, then 961/961 with the hash index on
  and off. `MERE_RUBY_VM=1 run_corpus.sh --both`: 961/961.
- capi_spec_check: 2420 of 2602, the recorded count. capi_mkmf_check passes.
  capi_gem_check: seventeen gems give the same output on both sides.
  headers_check: 194 headers, 10 patched, 22 vendored sources unchanged.

## Left

- Linux: capi_check on the VM was not run locally (it needs a reference
  ruby built for Linux). CI's Linux job runs it.
- Other tools that start mere-ruby with a scrubbed environment
  (capi_spec_check, capi_mkmf_check, capi_gem_check) still run the
  evaluator only. Whether each needs a `--vm` is a separate question; the
  contracts above are the ones that exercise the C API's own paths.
