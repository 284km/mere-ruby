# Ripper constant-named command calls

The A2 inventory records ripper/test_sexp.rb TestRipper::Sexp#test_command
as RED. Clean Ruby 4.0.10 returns command_call for a::C {}. The existing
translation returns call because it tests only arguments/BlockArgumentNode.
The actual Prism CallNode retains the :: operator, constant-named message,
brace block and all token locations; no parser position needs to be invented.

| Cause | Related unchanged test | Scope |
| --- | --- | --- |
| Constant-named receiver call with a brace block lacks command_call | ripper/test_sexp.rb test_command | Preserve :: versus . and parentheses versus command syntax. |

Branch base: d0843046. Add the narrow node-based classification and corpus
1121 before testing. Both full corpus sweeps, gates, record hygiene and
fixed-seed tight-GC RSS comparisons are pending. No full unit/Rails suite.


## Completed focused checks

Ordinary O2 candidate SHA-256:
ab193184c7d4225fee5dd611dab888fce53d79531b601eb0cd48f69b009854a5.
Mere compiler 9dec2ff6, mgz 661a01d8, clean Ruby 4.0.10 through
tools/ref_ruby.sh. Corpus 1121 matches all 11 rows, stderr and exit status
on evaluator and VM. The unchanged ripper/test_sexp.rb selections
test_command, test_def_fname and test_defs_fname pass 3 tests / 9 assertions
on reference and both candidates; pinned main 03694405 has 1 failure on
each engine (3 tests / 9 assertions). No upstream assertions are changed.

Max RSS bytes, /usr/bin/time -l, MERE_RUBY_GC_TIGHT=1, --seed=1:

| Engine | Main | Candidate |
| --- | ---: | ---: |
| Evaluator | 225591296 | 224837632 |
| VM | 226754560 | 228196352 |

All eight source gates, generated-C bracket depth, full and explicit record
hygiene and git diff --check pass. Both complete corpus sweeps below have now finished on the measured
candidate binary. No full unit/Rails suite or workflow change.

## Completed local acceptance

- `sh run_corpus.sh --both`: 958/958, hash index ON and OFF, exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: 958/958, ON and OFF, exit 0.
- Eight source gates, generated-C bracket depth, full/explicit loop hygiene
  and staged/unstaged whitespace checks: PASS.

Code, 11-row corpus and completed record are committed and pushed together.
The comparison main is explicitly pinned to 03694405; the branch starts
at d0843046. No whole unit/framework suite, workflow edit or reference gem
installation.
