# Rails R0: a cold baseline, Rails' own tests file by file, and default gem specs for a direct bin/rails

Rails plan R0. Three parts.

**The baseline.** Main `c521aa58` was measured cold by `railstest/measure.py`
(`railstest/main_cold_c521aa58.json`). The reference passes all six stages.
mere-ruby passes Bundler, the dependencies and the migration, and fails boot.
The dependency stage took 591.4 s of its 600-second bound. An earlier run of
`87ae563d`, made while the load average was 100 to 230, reached the bound in
the same stage. The bound is unchanged. A run that crosses it is retaken when
the machine is quieter, not waived.

**The boot failure.** A direct `bin/rails` runs `require "bundler/setup"`.
mere-ruby's `Gem.default_specifications_dir` was `/usr/lib/ruby/...`, which
does not exist. No default gem spec was registered, so RubyGems did not
activate Bundler as a gem. `bundler.rb` came from the reference library that
the harness appends as a fallback, and the activated spec claimed a path that
does not exist. The boot audit refused it. mere-ruby already has the rule for
this (`rlib9` in m_driver.mere, witness 655): a `<x>/lib/ruby/4.0.0` given on
`RUBYLIB`, with `gems/4.0.0/specifications/default` beside it, becomes the
tree of `rubylibprefix`. No other RbConfig path follows it. The harness gave
the library through `bootstrap.rb` only, so the rule never applied. Now
mere-ruby's side is also given it on `RUBYLIB`. The reference's side is not:
there it would put the library ahead of the gem home and select the default
Bundler, which was checked. The C API owner confirmed that mkmf and the native
gem builds do not read `rubylibprefix`. `capi_gem_check` already gives
`RUBYLIB` the same way.

**`railstest/framework/`.** This runs Rails 8.1.4.1's own test files on both
interpreters and classifies each test name as MATCH, RED, MISSING, BOTH or
EXTRA, with a state for each side's file. It uses a small locked Gemfile, each
side's own gem home, the tagged source copied per side, the 600-second / 2-GiB
bounds, and at most two processes at once. On `c521aa58`, the four
ActiveSupport files compared earlier give 539 MATCH / 2 RED of 541 (the two
titleize cases), the same as before. `check.py` (10 controls) runs in the
rails-harness workflow.
