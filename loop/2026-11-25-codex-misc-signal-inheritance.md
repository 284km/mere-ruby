# Inherited ignored INT and HUP signals

B11 was reproduced against the clean Ruby 4.0.10 oracle (a704b7cd95)
and main 323706a7, using the O2 Mere 9dec2ff6 build. No reference gems
were installed. Both evaluator and VM already return IGNORE for the
first Signal.trap(signal, DEFAULT) after exec inherits a real SIG_IGN
disposition. The inherited-state runtime change is present in main
(commit af1fe746), beyond the earlier fixture-only fix mentioned in the
request. No runtime change is needed for this witness.

Corpus 1110 sets the OS disposition in a shell immediately before exec,
then asks the new interpreter for its first trap return value. It covers
INT and HUP, stdout and exit status, on both engines, and matches Ruby.
The shell is used to establish the actual inherited state independently
of the parent's spawn defaults. A separate probe using Python's
preexec_fn to set SIG_IGN also matches on both engines.

A related difference remains in the host process-spawn backend: setting
IGNORE in a Mere parent before IO.popen does not preserve it into the
child as Ruby does. The startup-state witness above does not claim that
spawn difference is fixed; it needs a separate host-process investigation.

The candidate binary is exactly the unchanged main O2 binary. Its C API
headers are adjacent, and generated C for the unchanged source is emitted
for source gates. Full run_corpus.sh --both, the MERE_RUBY_VM=1 corpus,
source gates, bracket depth and record_hygiene are queued. No full unit
suite or Rails component suite was run, and no workflow is changed.

## Related unchanged upstream file

The selected test_signal.rb cases (trap_system_default, hup_me, and
ignored_interrupt) pass 3 tests / 20 assertions on the reference, main
and both candidate modes. Every run uses --seed=1 and tight GC; RSS bytes:

| Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| ---: | ---: | ---: | ---: |
| 170803200 | 169328640 | 173195264 | 174505984 |
