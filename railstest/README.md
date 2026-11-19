# Rails application measurement

This is a real Rails **8.1.4.1 application**, measured against Ruby 4.0.9.
It is not Rails' own framework test suite. Current main does not yet install
its complete dependency set: bigdecimal's native extension stops while
loading mkmf. Boot, migration, application tests and serving HTTP on mere-ruby
therefore remain **NOT_RUN**, not passing zero-test cases. See
[issue #116](https://github.com/284km/mere-ruby/issues/116).

The app uses the published Rails gem and its unchanged dependencies. It checks
SQLite migration, model autoloading, fixtures, validation/callbacks, CRUD,
transaction rollback, routes, ERB escaping, strong parameters, cookie/session
persistence, and an actual localhost HTTP request served by Puma. Its two test
files contain six tests / 31 assertions. These limited checks do not establish
full Rails, production, parallel-load or all-adapter compatibility.

`app/Gemfile.lock` pins all transitive versions and Ruby-platform package
checksums. `archives.lock.json` pins the same archives and Bundler 4.0.20:
69 source packages in total. Minitest 6.1.0 is used because the earlier gem
suite's 5.25.5 declares Ruby < 4.0. No package's Ruby requirements are bypassed.
Each interpreter runs RubyGems and the published Bundler executable, installs
into its own initially empty gem home, and builds its own extensions. The
reference's standard library is appended as a fallback on both load paths;
it does not precede Bundler's selected gem libraries. No reference
extension directories or installed gem homes are passed to mere-ruby.

## Restore and measure

Build mere-ruby normally at O2 first. Python 3.9+ and the usual native extension
build tools are required. Restoring archives is the network step; measurement
uses only those archives and frozen Bundler resolution. Native packages may
have their own vendored build dependencies. In this first run SQLite uses an
existing library's headers/library via its documented system-library option;
Nokogiri uses its vendored sources. Use the same options on both interpreters.

```sh
LANG=en_US.UTF-8 python3 railstest/measure.py restore \
  --archives /path/to/rails-archives

LANG=en_US.UTF-8 python3 railstest/measure.py measure \
  --archives /path/to/rails-archives \
  --reference /path/to/ruby-4.0.9/bin/ruby \
  --binary ./mere-ruby \
  --sqlite-prefix /path/to/sqlite-prefix \
  --output /path/to/new-rails-run
```

Omit `--sqlite-prefix` to use sqlite3's packaged SQLite build; that path also
requires pkg-config. The measured system SQLite was 3.46.1. It is an explicit
native-library choice, not a claim that packaged SQLite was measured.
The result records that choice. Output must be a new directory. Archives,
binary, lock and fixture hashes are checked, and the boot witness verifies
all activated locked gems' versions and source directories.

The six stages are Bundler installation, dependency installation, migration,
boot/source audit, application tests and real Puma HTTP. Each process family
has the existing **600-second / 2-GiB** bounds. Stdout and stderr, exits,
resource outcomes, peaks and stage states are saved separately. No database,
installed extension or output directory is reused between interpreters.
A failed stage prevents dependent stages from running. A healthy reference
is required; reference failure exits 2, a measured divergence exits 1, and
only all passing stages on both interpreters exit 0. `results.json` retains
NOT_RUN and resource events explicitly. The test stage requires all six named
tests, exactly 31 assertions and zero failures/errors/skips.

`latest.json` is the portable first measurement, including log hashes; raw
logs and built gems are external artifacts. This initial snapshot retains the
runner hash used for that run; later harness fixes do not rewrite history. Its main source is recorded in
`source_ref`; it does not describe unmerged gem or C API branches.

## First blocker and next measurements

On main `12ca1df2`, installing bigdecimal 4.1.3 executes mere-ruby but fails
loading mkmf with `undefined method '+' for nil`. The smaller
`probes/mkmf.rb` prints `rubyhdrdir_present=false`; reference prints true and
loads mkmf. PR #95 separately supplies real build/header metadata and owns
that integration. No C API, RbConfig or runtime function is changed here.
Replay this complete locked measurement after that work is available and
record the next failure without changing the dependency lock to avoid it.
The first error does not establish which later Rails features will work.

After installation: retain boot/source verification, migration, all six
application tests and Puma HTTP, then measure original ActiveSupport,
ActiveModel/ActiveRecord, ActionPack/ActionView and Railties tests in locked
source checkouts. Broader adapters, assets, jobs, mail and concurrent/durable
request workloads need additional explicit measurements.

## Harness checks

```sh
LANG=en_US.UTF-8 python3 railstest/check.py -v
```

Reference discovery and all measured stages discard inherited Ruby/Bundler
settings. The command-entry controls actually launch the measurement with
foreign RUBYOPT and a conflicting BUNDLE_GEMFILE; they must get beyond
discovery and report the deliberately invalid archive as reference-unavailable.

The controls reject changed/extra archives, inherited foreign gem/Bundler
settings, missing or skipped tests, reduced assertion counts, and success
markers accompanying nonzero exits or resource limits. They do not replace
the actual Rails run.

## Unmerged C API candidate

`capi_candidate.json` is a separate fresh measurement of #95 head 54184e4e,
not main. The same reference passes all six stages. Mere builds bigdecimal,
json, prism and racc, but the full dependency installation reaches its
unchanged 600-second wall bound (750,928 KiB peak). The four application
stages remain NOT_RUN. This supersedes no main baseline and is not an
installation PASS.

The next archive is Nokogiri 1.19.7. `probes/package_spec.rb` separates its
real SHA-256 and RubyGems metadata read without building any extension:

```sh
/path/to/ruby probes/package_spec.rb /path/to/nokogiri-1.19.7.gem
```

Run that script from this directory or use `railstest/probes/package_spec.rb`
from the repository root. RubyGems loads OpenSSL for package security; the
existing Digest SHA-2 implementation still evaluates its algorithm in Ruby.
The measured 4,387,328-byte archive exposes a checksum bottleneck before
Nokogiri's installation message. The independent SHA-2 implementation work
is separate from this measurement-only PR.

## Provider candidate and command registration

`provider_candidate.json` records the separate runtime composition at
153e64f5: unmerged C API #95 plus the SHA-2 provider implementation in #120.
Its exact source is retained on the explicitly validation-only
`rails-capi-probe-r1` branch. It is not main and is not a release candidate.

All six reference stages pass. Mere installs Bundler and all 68 frozen gems
in 284.529 seconds / 874,928 KiB, without a resource-limit event. The next
migration stage exits 1 before database migration: the command registry is
empty, so Rails::Command.invoke_rake calls perform on nil. Boot, application
tests and HTTP remain NOT_RUN. The earlier main and C API-only failures are
retained rather than replaced by this result.

`probes/subclasses_registry.rb` reduces the error to an ordinary Ruby module
singleton method, without Rails. `probes/command_registry.rb` inspects the
actual command names/namespace/registry in the installed app directory with
that side's environment. It does not populate the registry or change Rails.
[Issue #121](https://github.com/284km/mere-ruby/issues/121) tracks the shared
Ruby method-dispatch correction. The native invoke_val_c0 arm is outside
this measurement/library work's independent scope.


## Independent load diagnostics

`load_diagnostics.json` keeps two follow-up diagnostics separate from the
six original stages. They reuse each interpreter's own already-built gems
and fresh copies of the unchanged app fixture; they do not repeat the cold
installation or execute the original CLI. The original main/C API/provider
records and their NOT_RUN stages are unchanged.

Directly running the existing `script/boot.rb` on the provider composition
153e64f5 passes reference source provenance and boot, but mere-ruby stops
loading ActiveSupport's i18n railtie at `config.i18n.railties_load_path = []`.
`probes/ordered_options.rb`, run with the isolated app as working directory,
reduces this to unchanged ActiveSupport OrderedOptions. Construction has
the correct subclass and Ruby method owner; its dynamic accessor is not
called. The failed earlier preparation that loaded Railtie without its
required setup is not a healthy-reference measurement and is not included.

`probes/hash_missing.rb` reproduces the missing Ruby hook without any gem.
The same Hash subclass instance reports its correct class, then ordinary
unknown calls bypass its Ruby method_missing and raise instead. See
[issue #123](https://github.com/284km/mere-ruby/issues/123). The gem session's
primitive method/missing-hook paths own this boundary. Neither those shared
functions nor another session's branch is edited here. This is separate
from #121's command registry. The full Rails workload still needs its
original migration/boot/test/HTTP replay after both dispatch fixes.


## Class-dispatch candidate with the original CLI

`class_candidate.json` is a new cold paired measurement of validation-only
composition 5d1a0c95: current unmerged C API #95, bounded SHA-2 #120 and
Class dispatch #125. Its exact source remains on rails-capi-probe-r1,
which is explicitly not a merge/release branch. Each side again starts
with an empty gem home and builds its own extensions from the same lock.

Reference passes all six original stages. Mere installs all 68 dependencies
in 231.607 seconds / 946,832 KiB, without a resource event. The original
migration CLI now enters Rake and loads the application instead of failing
on an empty command registry. It then fails in ActiveSupport's existing
railties_load_path= assignment (#123), exit 1 in 3.238 seconds / 305,664 KiB.
Boot, tests and HTTP remain NOT_RUN. Original 600-second / 2-GiB bounds,
lock, app and source checks are unchanged. Earlier observations are kept.


## Native-build children and the declared reference fallback

The validation-only Class/Hash/gem composition a9c8a2ff has a separate cold
record in load_path_candidate.json. Reference passes all six stages, but
Mere dependency installation stops at bigdecimal (33.243 s / 620,816 KiB,
exit 5, no resource event): RubyGems' unchanged native builder passes its
reference source directory through -I, so monitor.rb asks for monitor.so.
The four application stages remain NOT_RUN. This failed run is preserved;
the Hash hook is not reached in it.

The intake bootstrap now moves only its explicitly declared reference
fallback behind the interpreter's own libraries, including when inherited
through a child's -I. RUBYOPT defers automatic RubyGems startup until the
bootstrap restores that order, then requires unchanged RubyGems on both
interpreters. Otherwise RubyGems can load monitor before any -r bootstrap.
The reference's own stdlib order and all other explicit source directories
remain unchanged. No require implementation, RubyGems/Rails/gem source,
RbConfig value or API inventory changes. This
is the intake counterpart of #90's mspec/corpus fallback-ordering repair;
it does not change that PR or globally suppress physical library overrides.

A real child-CLI control first fails on a foreign monitor wrapper, then
loads the runtime's monitor after the bootstrap. Another explicit source
still wins over the fallback, and reference-own path order is identical.
The original archives/app/limits and historical JSON files are unchanged.
The workload must be replayed cold with this bootstrap before claiming
any later stage passes.
