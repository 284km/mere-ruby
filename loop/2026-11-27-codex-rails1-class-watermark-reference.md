# class-watermark-reference

The class-watermark gate validated `REF_RUBY_BIN` but ran its comparisons with bare `ruby`. An
explicit clean Ruby 4.0.10 reference alongside system Ruby 2.6.10 therefore produced false failures
for all three fixtures on both engines. Use the selected, quoted binary for the three positive
comparisons and the negative control. The change is two shell lines; interpreter, parser, C API and
library sources are unchanged from main `e433affa596f582782b1c6932811a6461619faca`.

Measured revision `c68753474389bcc7dd1e2aec689d3465347b6ddc`; ordinary O2, Mere 9dec2ff6, mgz
661a01d8. One exact main-code binary
(`5ac78249c0853a38252817e67e82f180a1b013a1be1d285acee7af805018c88c`) is used for both the original
and corrected gate. Reference: `tools/ref_ruby.sh`, clean Ruby 4.0.10, revision
a704b7cd95a42cc0cf5f307137bf3aac0285b915, Prism 1.8.2, no extra gems.

Regression check: put a `ruby` canary that logs invocation and exits 86 first on PATH while setting
`REF_RUBY_BIN` to the clean reference. The original script invokes it four times and fails; the
corrected script never invokes it and passes all six positive engine/fixture checks. The
no-scan/no-watermark negative control still loses its class. Fixtures: corpus 559, 561, 839; no new
Ruby corpus fixture is needed for a shell reference-selection correction.

- `run_corpus.sh --both`: 1029/1029, hash indexes ON/OFF.
- VM corpus: 1029 VM / 0 evaluator fallback / 0 differences.
- All source gates including class_watermark pass with only explicit REF_RUBY_BIN selection, without
  a PATH override; default and explicit loop record hygiene pass.

Related CRuby file `ruby/test_method.rb` (fixed seed 1), covering retained method owners/binding:
the same exact runtime binary is used before/after this tooling-only change. Case inventories and
results are identical on both engines. Existing failures and skips remain explicit.

| Mode | Tests | Assertions | Failures | Errors | Skips | Max RSS (KiB) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| reference | 99 | 564 | 0 | 0 | 0 | 201456 |
| before-evaluator | 99 | 556 | 1 | 0 | 1 | 751792 |
| after-evaluator | 99 | 556 | 1 | 0 | 1 | 767648 |
| before-vm | 99 | 556 | 1 | 0 | 1 | 1648896 |
| after-vm | 99 | 556 | 1 | 0 | 1 | 1508480 |

Every run is COMPLETE with no wall/memory limit event. These single RSS samples are
allocator/load-sensitive; no runtime memory or instruction improvement is claimed. No
runtime/frame/block change or Rails behavior change is involved, so no Rails file result is claimed
for this correction.

The unchanged integration runtime initially exposed the gate bug with system Ruby 2.6.10 on PATH.
Its corrected-reference gate cohort passes all checks when the clean reference bin is first on PATH;
the failed attempt is retained separately. This PR removes the need for that PATH workaround.

Proof identifiers: measured binary SHA256 above; generated-C SHA256
`f18fa8b3ab69ec032ae2bf33a65a342b3ce4a0c217873f2e221ef16ea44b09c2`; reference binary SHA256
`5ad9092ceb67b18b9ed512ad3fbcf309910c7ad7d2fabb3d85d5228a51eb8df0`. Full corpus and VM checks retain
source/binary identity throughout.
