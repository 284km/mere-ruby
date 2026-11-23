# Rails G1: a cold run of main passes all six stages

`railstest/main_cold_d434c81e.json` is the application measurement run cold
on main `d434c81e`. It uses the unchanged fixture, lock and archives, the
system SQLite 3.46.1 and the Mere compiler `0c083af0`. Both interpreters pass
Bundler, the dependencies, migration, boot from the direct `bin/rails`, the six
tests (31 assertions) and Puma's real HTTP, with no resource event. mere-ruby's
dependency stage took 232 s of its 600-second bound, at a load average of about
12. The previous baseline's 591 s was taken while the machine was much busier.

Three changes made the difference since the `c521aa58` baseline (boot FAIL):
- #173 gives mere-ruby's side the standard library on `RUBYLIB`, so RubyGems
  sees default gem specs and activates the installed Bundler.
- #172 fixes the Ruby semantics behind the test errors: saved native operators
  (ActiveSupport's `Time#<=>`), Comparable after a program's `#<=>`, `super`
  into IO/Time builtins (io-console's `tty?`), and `super` into a builtin alias
  (`send_action`).
- #177 runs a C function without the GVL on a worker thread, so nio4r's
  selector no longer stops every Ruby thread and Puma answers.
