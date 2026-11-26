# A1: Cargo shared-library suffix metadata

Branch base: 03160dc94142b2e527ed8d1ac67490384b931680. The clean Ruby 4.0.10 aggregate report at main
c0a5f15b records four Cargo-builder REDs. Before changing code:

| File | Test | Recorded failure / proposed cause |
| --- | --- | --- |
| rubygems/test_gem_ext_cargo_builder.rb | test_build_cdylib | Dynamic library not found. |
| rubygems/test_gem_ext_cargo_builder.rb | test_custom_name | Installed Rust extension cannot be required. |
| rubygems/test_gem_ext_cargo_builder.rb | test_full_integration | Installed Rust extension cannot be required. |
| rubygems/test_gem_ext_cargo_builder.rb | test_rubygems_cfg_passed_to_rustc | Dynamic library not found. |

RubyGems CargoBuilder chooses lib<crate>.<SOEXT>, then copies that native
shared library to <crate>.<DLEXT>. RbConfig currently supplies DLEXT but
omits SOEXT; on Darwin the two real suffixes differ (dylib versus bundle).
The native build metadata must name its actual platform shared-library
suffix. No native C API function, RubyGems test, exclusion or resource
budget is changed. These archived failures still need current-main
reproduction and acceptance before a PR is published.

Use clean tools/ref_ruby.sh, one selected file at a time, --seed=1 and
tight GC for reference/main/candidate comparisons. Never install gems
into the reference Ruby: only upstream tests' isolated temporary gem homes
are allowed. Full corpus in both modes, source gates, bracket depth and
full/explicit hygiene remain required; no full unit/Rails suite.

Main 03694405 is integrated locally before final acceptance so the Cargo
comparison shares the current native-module implementation. No push is
made until all local acceptance results are recorded.


## Fair toolchain comparison and C API boundary

The unchanged upstream Cargo file is now run with existing Rust/Cargo
1.99.1 and the suite's GEM_TEST_TMPDIR outside the reference source
workspace. Cargo 1.80.1 cannot parse the edition-2024 parent workspace;
using the suite's normal external temporary directory avoids that unrelated
fixture/toolchain error. No reference gems or upstream assertions change.
Clean Ruby 4.0.10 passes 4 tests / 18 assertions. Main 03694405 on both
engines has 4 tests / 10 assertions, 2 failures and 2 errors. The candidate
has 4 tests / 12 assertions, 2 failures and no errors: test_build_cdylib and
test_rubygems_cfg_passed_to_rustc now pass. Corpus 1120 matches stdout,
stderr and status on evaluator and VM.

The two remaining integration LoadErrors are separate from SOEXT. An
instrumented diagnostic (excluded from acceptance) preserves Open3's actual
return and records successful gem build/install and successful Rust
compilation. The installed rust_ruby_example.bundle is 388976 bytes and
contains no rb_mere_extension_abi marker. capi/core.c mr_capi_probe correctly
rejects it before loading. The genuine artifact is preserved privately.
This C API/Rust extension compatibility cause is reported to the owner;
no ABI guard is relaxed and no foreign extension is falsely accepted.
The separate unchanged custom-name test now confirms the same boundary:
gem install succeeds, but its installed custom_name_ext.bundle is 388304
bytes and also lacks rb_mere_extension_abi. Both real artifacts are
preserved privately. Both remaining integration failures therefore belong
to C API/Rust extension compatibility, separate from this SOEXT correction.

Max RSS bytes, fixed --seed=1, MERE_RUBY_GC_TIGHT=1, /usr/bin/time -l:

| Engine | Main | Candidate |
| --- | ---: | ---: |
| Evaluator | 419446784 | 436043776 |
| VM | 422297600 | 455294976 |

These whole-file process maxima include the Rust compiler children, so
they are not presented as an interpreter heap delta. Reference max RSS is
415956992. The ordinary O2 candidate SHA-256 is
170bcd3d6fcd52be9e18698dab16ccca7eaf16ef75553d673a6a6664f813bcf5.
Compiler 9dec2ff6, mgz 661a01d8. The complete corpus and final source checks below finish this suffix correction;
this does not claim all four Cargo tests are fixed.

## Completed local acceptance

- `sh run_corpus.sh --both`: 954/954 programs match Ruby with hash index ON and OFF; exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: 954/954, ON and OFF; exit 0.
- Both sweeps used the same ordinary O2 binary identified above.
- The eight source gates, generated-C bracket depth, full and explicit
  loop record_hygiene and staged/unstaged whitespace checks pass.

The main comparison is pinned to 03694405, including native module insertion.
The measured remaining ABI failures are transferred to the C API stream.
No full unit/framework suite, workflow edit or reference gem installation.
