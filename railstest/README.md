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
