# Rails application measurement

This is a real Rails **8.1.4.1 application**. The harness targets Ruby 4.0.10;
the historical measurements below retain their recorded reference versions.
It is not Rails' own framework test suite; that one is measured by
[`framework/`](framework/README.md).

**G1 reached: [`main_cold_d434c81e.json`](main_cold_d434c81e.json).** A cold
run of main `d434c81e` passes all six stages on both interpreters, with no
resource event. mere-ruby: Bundler 4.8 s, the dependencies 232.1 s (peak
1.63 GB), migration 10.2 s, boot from the direct `bin/rails` 7.4 s, the six
tests (31 assertions) 11.8 s, and Puma's HTTP 11.0 s. The reference: 0.9,
148.4, 4.9, 1.5, 1.7 and 1.9 s. The load average was about 12 when it
started. This took the saved native operators and super into builtins (#172),
default gem specs on `RUBYLIB` (#173), and a C function without the GVL
running while other threads run (#177).

**On both executions: [`cold_2c167cfd_evaluator.json`](cold_2c167cfd_evaluator.json)
and [`cold_2c167cfd_vm.json`](cold_2c167cfd_vm.json).** Cold runs of `2c167cfd`
(on main `17a5db5f`) pass all six stages on the evaluator and, with
`--mere-env MERE_RUBY_VM=1`, on the ISeq VM. mere-ruby boots in 6.6 s on the
evaluator and 10.3 s on the VM (the reference: 1.6 s); the six tests take
11.6 s and 14.6 s (1.8 s), Puma's HTTP 9.9 s and 12.6 s (2.3 s). The load
average was 7 to 9. `loop/2026-11-24-stage10-rails-vm-time.md` has the table.

The earlier baseline: [`main_cold_c521aa58.json`](main_cold_c521aa58.json), a
cold run of main `c521aa58` (its `source_ref` is a work-in-progress commit
that adds only `railstest/` files on top of it). It used the harness before
`RUBYLIB` was given to mere-ruby. The reference passes all six stages.
mere-ruby passes Bundler, the dependencies (591.4 s of the 600-second bound,
at a load average of about 35 when the run started) and the migration. Boot
fails: the direct `bin/rails` did not activate Bundler as a gem (see below).
Tests and HTTP are NOT_RUN. An earlier cold run of `87ae563d` reached the
600-second bound in the dependency stage while the load average was 100 to
230. It is not kept as a baseline.

The history below is kept as it was. Main `2e2ab568` installed all
68 frozen dependencies, including bigdecimal's native extension, within the
existing bounds. The next migration command fails at the separate command
registry boundary in [issue #121](https://github.com/284km/mere-ruby/issues/121).
Boot, application tests and HTTP on mere-ruby remain **NOT_RUN**. The first
main snapshot's mkmf failure in [issue #116](https://github.com/284km/mere-ruby/issues/116)
is retained as history; the fresh integrated-main replay is
[`main_native_install.json`](main_native_install.json).

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
mere-ruby is also given that library on `RUBYLIB`, which is how it takes its
standard library: a `lib/ruby/4.0.0` with `gems/4.0.0/specifications/default`
beside it makes those default gem specs visible to RubyGems (only
`rubylibprefix` follows it; `prefix`, `rubylibdir`, `archdir`, `rubyhdrdir`
and the compiler settings do not change). Without them `require
"bundler/setup"` from a direct `bin/rails` did not activate Bundler as a gem:
it read `bundler.rb` from the fallback library, and the boot audit found a
Bundler outside mere-ruby's gem home. The reference is not given `RUBYLIB`;
there it would put its library ahead of the gem home and select its default
Bundler.

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
  --reference /path/to/ruby-4.0.10/bin/ruby \
  --binary ./mere-ruby \
  --sqlite-prefix /path/to/sqlite-prefix \
  --output /path/to/new-rails-run
```

`--mere-env MERE_RUBY_NAME=VALUE` (repeatable) sets a variable of mere-ruby's
own on its side only, and the result records it as `mere_env`:
`--mere-env MERE_RUBY_VM=1` measures the ISeq VM. Every inherited `MERE_RUBY_`
name is still dropped.

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


## Hash candidate reaches the locked JSON generator

hash_candidate.json is the fresh original-CLI replay on validation-only
source 0b76e819, with C API #95, bounded SHA-2 #120, reviewed Class #125,
Hash #126 and the intake child-startup correction. The runtime binary is
unchanged from a9c8a2ff; only the measured startup inputs changed. Its full
735-file corpus matches with indexing ON and OFF. The same frozen archives,
fresh gem homes/native builds and 600-second / 2-GiB bounds remain.

Reference passes all six stages, including six tests / 31 assertions and
real Puma HTTP. Mere installs all 68 dependencies in 201.059 seconds /
948,608 KiB, then the original migration CLI passes the Hash configuration
and fails on JSON::Ext::Generator::State.default_sort_keys_proc= (2.273 s /
268,896 KiB, exit 1, no resource event). Boot/tests/HTTP remain NOT_RUN.
The earlier main, C API, provider, Class and load-path records are unchanged.

The actual JSON 3.1.0 Ruby facade loads, but shipped parser/generator source
is selected despite the activated gem's independently built native files
earlier on the load path. probes/json_generator.rb is a gem-only ordinary
require reproduction. Issue #127 tracks native feature selection; no JSON
attribute, source patch or forced older gem conceals it. Explicitly loading
the own native libraries after the failed facade is a separate diagnostic
whose sorting/parsing output matches; it is not used by the original run.
Full Rails component suites remain unmeasured, and no Rails app pass is claimed.


## Native-selection candidate reaches Module's included super

native_candidate.json preserves the next fresh original-CLI paired run on
validation-only source 61d01f6d, including native selection #128. Each runtime
again installs from the same lock into an empty home and builds its own
extensions. All six reference stages pass, including six tests / 31 assertions
and real Puma HTTP. Mere installs all 68 dependencies in 232.699 seconds /
954,624 KiB and passes the previous registry, Hash and JSON boundaries.

Migration then exits 1 in 4.097 seconds / 318,224 KiB at ActiveModel's
respond_to_without_attributes? on its AttributeMethods module. Boot/tests/
HTTP remain NOT_RUN; there is no resource event. The original app, lock and
600-second / 2-GiB bounds are unchanged, and earlier records are retained.

An independent TracePoint diagnostic identifies the original missing call
as included. probes/module_native_hook.rb reduces it without gems: a Ruby
included override's super misses Module's native default and calls an
unrelated instance method_missing on the module itself. Reference returns
the real nil result. The same failure occurs on the Hash parent, so it is
not claimed as introduced by the native-file correction. Issue #129 hands
this ordinary native-super/notification boundary to the generic dispatch
work. No Rails alias or notification return is fabricated to conceal it.

The preceding JSON probe now matches using normal require, with no native
preload workaround. Original require/autoload/Marshal counts and all 733
native-branch corpus files match their stated comparisons; existing C API
contracts hold normally/under stress and all six fault controls fail. These
do not establish a Rails application or framework-suite pass.


## Module notification candidate reaches ActionController syntax

module_candidate.json preserves the fresh paired replay on validation-only
source b9056808, including notification correction #132 and the synchronized
native-selection parent. Both sides use the original 69 locked source
archives, initially empty homes and independently built native extensions.
All six reference stages pass, including six tests / 31 assertions and real
Puma HTTP. Mere installs all 68 dependencies in 210.753 seconds / 862,800 KiB.

The original migration CLI passes the preceding Module included failure and
then exits 1 in 3.999 seconds / 318,752 KiB at unchanged ActionController
source: extend ::AbstractController::Railties::RoutesHelpers.with(app.routes).
The parser reports expected end of statement. Boot/tests/HTTP remain NOT_RUN;
there is no resource event. Earlier records, app sources, lock and 600-second /
2-GiB bounds are unchanged; all 18 new stdout/stderr hashes were verified.

probes/absolute_extend.rb reduces the absolute-root factory argument without
gems and checks lexical anchoring. Even the single original extend statement
fails syntax checking on unchanged main and this composition, while Ruby
accepts it. The bare absolute constant, adjacent keyword command and property
assignment controls parse on both. Issue #134 records parse_stmt_id's special
extend branch consuming only the scoped constant and leaving the dotted
call unparsed. No Rails source patch or changed grammar input conceals it.

The independent #132 notification branch completes 707/707 corpus programs
with indexing ON/OFF and preserves all five core files (525 MATCH / 527 cases).
The synchronized #128 branch separately completes 734/734 programs. Neither
is a full-corpus claim for this combined b9056808 composition. A separate
pre-existing saved native Method metadata gap is tracked in issue #133; its
Array#length control fails on the parent and is not an actual Rails blocker.
Rails application and framework-suite success remain unestablished.


## Integrated main gets beyond the original native-build blocker

`main_native_install.json` records a new cold run on main `2e2ab568`, after
the build metadata/C API integration in #95 and SHA-2 provider integration
in #120 were merged. The normal O2 build uses main's pinned Mere `01f5ad73`.
The unchanged 69 archive locks, fixture, runner, bootstrap and per-stage
600-second/2-GiB family bounds are retained. Both interpreters start with
empty gem homes and build their own extensions. SQLite again uses its
documented system-library option with the same 3.46.1 library on both sides.

Reference Ruby 4.0.9 passes all six stages, including six application tests /
31 assertions and actual Puma HTTP. Its dependency installation takes
163.412 seconds / 1,733,168 KiB. Mere installs Bundler and all 68 dependencies;
dependency installation exits 0 in 253.379 seconds / 914,976 KiB without a
resource event. The actual bigdecimal 4.1.3 Makefile uses this interpreter's
own headers and completes its native build/install. The existing small
`probes/mkmf.rb` also prints `rubyhdrdir_present=true` and `mkmf-loaded` on
both interpreters; a separate check verifies the real `capi/include/ruby.h`.

The next original migration command exits 1 in 2.062 seconds / 199,616 KiB:
Rails::Command.invoke_rake calls perform on nil, the independently reduced
singleton subclasses/command-registry issue #121. Boot/tests/HTTP remain
NOT_RUN and the complete record remains RED. This meets #116's acceptance
condition of getting beyond the first extension build; it does not establish
a Rails application or framework-suite pass. The first main and every
unmerged-composition record above remain unchanged. Runtime functions changed
for this replay: none. All seven measurement harness controls pass.
