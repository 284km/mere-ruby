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
