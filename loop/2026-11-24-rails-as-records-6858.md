# ActiveSupport records of 68588737 (main 03c2869a), evaluator and VM

Three records were added to `railstest/framework/records/`, described in its
README: `install-68588737.json`, `activesupport-68588737.json` and
`activesupport-68588737-vm.json`. The build that ran the files is the build
that installed mere-ruby's gem home, so there is no `--other-install-binary`.

| | MATCH | RED | MISSING | BOTH |
|---|---|---|---|---|
| `8bf5563b` (previous record) | 4,675 | 63 | 1 | 29 |
| `68588737`, evaluator | 4,546 | 34 | 159 | 29 |
| `68588737`, `MERE_RUBY_VM=1` | 4,667 | 31 | 41 | 29 |

`compare` against `8bf5563b` exits 1. The only MATCH lost is
`json/encoding_test.rb` (154), stopped at `require "bundler/setup"` by
the `split` collection bug that #195 fixes. With that build, the file runs
158 MATCH. Eight other files gained 25 MATCH between them.

## Where the RED are

The VM's 31 RED are the same tests as the evaluator's 31 that remain after
`error_reporter_test.rb` (1) and `deep_mergeable_test.rb` (2), which are
evaluator-only.

- Rails (this flow): `hash_with_indifferent_access` 4, `deprecation` 4 and
  `deprecation/proxy_wrappers` 3, `core_ext/time_ext` 4 (offsets around DST),
  `core_ext/enumerable` 3, `descendants_tracker` 2, `deep_mergeable` 2,
  `core_ext/object/try` 2, and one each in `array/wrap` (Struct),
  `numeric_ext`, `string_ext` and `inflector` (titleize), `symbol_ext`,
  `time_with_zone`, `gzip`, `logger` and `error_reporter`. `duplicable` has
  one MISSING. The next round's branch already covers `try`, the Struct in
  `wrap`, `symbol_ext`, `deep_mergeable` and Range#sum in `enumerable`.
- `time_travel_test.rb` 1 (`test_time_helper_travel_with_time_subclass`):
  owner not yet checked.
- VM only: the two `xml_mini` nokogiri files stop with `Nokogiri::HTML is not
  a module`. Reopening a module through a constant that names it,
  `H = H4; module H; end`, raises on both interpreters at the top level and
  only on the VM inside a module. The evaluator's half is this flow's next
  round. The VM's half goes to the VM flow after that.
