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
