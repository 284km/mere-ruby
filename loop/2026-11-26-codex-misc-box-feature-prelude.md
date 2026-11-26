# A1: load real prelude features before the Box program

Branch from current main 4920ac75. The inventory's unchanged original
ruby/test_box.rb prelude case fails on both Mere engines because
bundled_gems.rb and error_highlight.rb have not actually been required.
Clean Ruby 4.0.10 loads both before the program with gems enabled and
neither with --disable=gems. This was checked before changing the runtime.

| Cause | Required behavior |
| --- | --- |
| Gem prelude only requires rubygems | Require the actual bundled_gems file after RubyGems. |
| ErrorHighlight feature is accepted but not booted | Load the real error_highlight file before -r/script, honoring its feature flag. |
| New Box repeats only RubyGems boot | Each Box must perform the same actual feature loading with its own loaded-feature list. |

Use actual require operations, never insert pretend loaded features.
The portable corpus uses ordinary temporary Ruby files to observe load
availability, actual file-body execution, require ordering and flags; original CRuby cases exercise the real libraries.
Related original-file comparisons, both corpus sweeps, source gates,
record hygiene and fixed-seed tight-GC RSS remain pending. No workflow
change and no reference gem installation.

## Focused original-file acceptance

Corpus 1130 has five child-process cases covering actual file-body execution,
load order before -r, new Box loading and feature-flag ordering. Stdout,
stderr and exit status match clean Ruby on both engines.

Unchanged CRuby ruby/test_box.rb, test_prelude_gems_and_loaded_features and
its with_disable_gems counterpart, fixed --seed=1 and tight GC: reference
2 tests / 14 assertions PASS; main 4920ac75 both engines 2 / 11, one failure;
candidate both engines 2 / 14 PASS. No upstream assertions are changed.

| Max RSS bytes | Reference | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| Original two tests | 23642112 | 179961856 | 169754624 | 179650560 | 173473792 |

Ordinary O2 candidate SHA-256
3e3ec0be8ac9f98199e712a2e7341300bc9d91b78f11fa905f9f38dcdc77a6a8,
compiler 9dec2ff6, mgz 661a01d8. Complete corpus sweeps remain queued.


## R2 current-main prelude integration

Integrate exact main ee9cf5dc7044092e97f6e86aca0ec58fa5b1d741, including
merged SyntaxSuggest and Box identity fixes. Resolve the adjacent CLI feature
arms by preserving both error_highlight and syntax_suggest switches. Main
boot loads real bundled_gems and error_highlight before the existing
SyntaxSuggest core extension; each new Box keeps its own real feature loads.
No loaded-feature entry is invented. R1 evidence is historical. Fresh R2
focused cases, matching-main original selections, tight-GC seed-1 RSS/startup
cost, both full sweeps and gates remain pending before publication.


### Completed R2 focus and startup measurements

The gem prelude now actually requires bundled_gems after RubyGems and loads
error_highlight before -r or the program when enabled. Each Ruby::Box performs these
requires with its own feature list. The error_highlight feature switch honors
enable/disable ordering; main's syntax_suggest feature and boot sequence are retained.
No loaded-feature entries are fabricated.

Corpus 1130 covers five child configurations, actual library-body execution, preloads,
Box isolation and feature-switch ordering. It matches clean Ruby 4.0.10 stdout, stderr
and status on evaluator and VM. Compatibility controls 1109, 445 and 1112 also match
on both engines. Original unchanged ruby/test_box.rb prelude_gems_and_loaded_features
and with_disable_gems selections pass 2 tests / 14 assertions on reference and
candidate; exact main ee9cf5dc has 2 / 11, one failure on both engines. Fixed
--seed=1, MERE_RUBY_GC_TIGHT=1, one file at a time.

Original-file maximum RSS bytes:

| Selection | Reference | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| Box prelude | 23281664 | 171474944 | 168673280 | 172916736 | 169558016 |

Startup uses three alternating matching-main/candidate ordinary O2 pairs with
MERE_RUBY_GC_TIGHT=1 and parsed --seed=1. The disabled control is measured in each
iteration. Instructions and seconds are medians; RSS is the maximum of three samples.
Standalone and reference-stdlib configurations are measured separately.

| Configuration | Engine | Main instructions | Candidate instructions | Change | Main/candidate seconds | Main/candidate max RSS bytes | Disabled instructions | Disabled max RSS bytes |
| --- | --- | ---: | ---: | ---: | --- | --- | ---: | ---: |
| standalone | evaluator | 943481938 | 943473156 | -0.001% | 0.096 / 0.094 | 71778304 / 71860224 | 944079579 | 71843840 |
| standalone | VM | 938410329 | 939121253 | +0.076% | 0.094 / 0.090 | 72482816 / 72515584 | 939693313 | 72515584 |
| reference_stdlib | evaluator | 2514678034 | 2662034533 | +5.860% | 0.276 / 0.315 | 111951872 / 120897536 | 2555978746 | 115458048 |
| reference_stdlib | VM | 2521533163 | 2663213432 | +5.619% | 0.282 / 0.305 | 112623616 / 120750080 | 2557090690 | 115949568 |

Actual feature probes confirm that standalone has none of the three external prelude
libraries. With reference stdlib available, main loads rubygems only; candidate loads
rubygems, bundled_gems and error_highlight. The disabled candidate loads rubygems and
bundled_gems. Both engines agree, without warnings. Standalone instruction ranges
overlap; reference-stdlib ranges do not. The real extra library loading costs +5.860%
evaluator / +5.619% VM instructions and about 8–9 MB additional maximum RSS. These
costs are reported explicitly; standalone timing does not stand in for the changed
loading path.

Fresh integrated candidate O2 SHA-256
cf6a4e69690e04b78e681d835351bbfb330c323f77925509ea7c2e477b2b89b7; matching main
SHA-256 94dd4c3e662ca569d5c5c7d5b5320cdf81e1263f4ac626f73ab199fb09fbbe89. The
integration base is exact main ee9cf5dc7044092e97f6e86aca0ec58fa5b1d741. The
matching-main executable is a verified immutable reuse: all 2706 tracked regular
source files matched that commit before/after snapshot, with original successful O2
build record, dependency hashes, compiler 9dec2ff6 and mgz 661a01d8. It is not
described as a fresh main build. Both full sweeps use the same candidate binary.

Completed R2 publication acceptance: `sh run_corpus.sh --both` and
`MERE_RUBY_VM=1 sh run_corpus.sh --both` each pass 989/989 programs,
hash index ON/OFF, exit 0. Both binary proofs match the R2 SHA above.
Eight source gates, generated-C bracket depth, full/explicit completed
record hygiene and staged/unstaged whitespace checks pass. Integration
code and completed record are pushed together.
