# Rails' own component tests, file by file

This runs the test files of Rails 8.1.4.1 itself (`activesupport/test`,
`activemodel/test`, ...) on the reference Ruby 4.0.9 and on mere-ruby, and
compares them test by test. It is the measurement for the framework half of
the Rails plan. The application in `railstest/app` is measured separately by
`railstest/measure.py`.

## What is fixed

- **Rails source**: tag `v8.1.4.1` (`3f290b759c8e2ffe7c257951b1255740751355e4`).
  `run` refuses another commit or a checkout with local changes. Each side
  gets its own copy of the tagged tree (`git archive`), because tests write
  beside themselves and the two sides run at the same time.
- **Gems**: `Gemfile` and `Gemfile.lock` hold the published Rails gems,
  sqlite3, minitest, and five test-only gems. The test-only gems are
  minitest-mock, rexml, rack-cache, bcrypt and msgpack, at the versions in
  Rails' own lock. minitest (6.1.0) and sqlite3 (2.10.2) are the
  application's locked versions, not Rails' (6.0.6 and 2.9.4). One lock for
  both measurements keeps one set of native builds to trust, and Rails 8.1.4.1
  accepts both. The lock was made from the application's lock with
  `bundle lock --conservative`. That drops puma and adds the five gems.
  `archives.lock.json` pins all 73 archives with their SHA-256.
  Rails' own Gemfile is not used: it pulls in external-service gems
  (mysql, redis, selenium, ...) and documentation tools.
- **Component code**: the tests take `lib/` from the installed component gems.
  `install` checks the Rails checkout against the locked commit, requires all
  twelve component gems to be installed, and checks that each one's `lib/` is
  byte-identical to the tagged source's `lib/`. It fails otherwise.
- **Bounds**: each file runs under the same 600-second / 2-GiB process-family
  bounds as the rest of the project. **At most two processes run at a time**:
  the machine is shared. `--jobs 2` runs the two sides at once, each side
  running its files **one after another**, because a side's files share its
  tree copy, gem home and TMPDIR (activerecord's sqlite3 tests share one
  fixture database). `--jobs 1` runs everything in sequence.

The native extensions in a gem home were built by the interpreter that
installed them (for mere-ruby, against its C API). `run` therefore refuses a
binary other than the one recorded by `install`. With
`--other-install-binary` it runs anyway and records both hashes
(`install_binary_sha256` beside `binary_sha256`). A new mere-ruby build is
measured after it has installed its own gem home.

## Environment

Both sides use the application measurement's bootstrap (`../bootstrap.rb`),
with their own gem home and Bundler, and a scrubbed environment. mere-ruby is
also given the reference standard library on `RUBYLIB`, as in `../README.md`.
That is how mere-ruby sees default gem specs. The reference is not.

A file runs from the component directory as

    ruby -w -Itest test/<file> -v --seed 12345

This is close to, not the same as, the component Rakefiles at the tag. They
use `Rake::TestTask`, which adds `-Ilib` and runs files through rake's loader,
and they set `RAILS_MINITEST_PLUGIN=true`. Here, on purpose:
- there is no `-Ilib`: `lib/` comes from the installed gem, which `install` has
  checked is the tag's `lib/`;
- there is no `RAILS_MINITEST_PLUGIN` (all `RAILS_*` settings are removed): the
  transcript stays minitest's own `-v` format, which is what is parsed;
- one file per process, so a crash or a bound stops one file only.

`RAILS_STRICT_WARNINGS`, `BUILDKITE` and `CI` are removed, so warnings are not
errors on either side. Inherited `MERE_RUBY_*` settings are removed too.
`--mere-env MERE_RUBY_VM=1` (repeatable, `MERE_RUBY_*` only) gives a setting
to mere-ruby's side, so that the VM can be measured instead of the evaluator.
The results record it as `mere_env`.

A component may need a setting of its own, such as activerecord's `ARCONN=sqlite3`.
`run --env NAME=VALUE` (repeatable) gives it to both sides alike, and
`results.json` records it under `env`. Because the record is published, the
runner refuses:
- a NAME it makes itself for each side (the gem home, `RUBYOPT`, `RUBYLIB`,
  `TMPDIR`, `BUNDLE_*`, ...);
- `MERE_RUBY_*`, which is mere-ruby's alone;
- a NAME that looks like a secret (`TOKEN`, `SECRET`, `PASSWORD`, ...);
- a VALUE that holds a path of this machine.

## Verdicts

Each test name the reference reports gets one verdict:

| verdict | meaning |
|---|---|
| MATCH | passed on both sides |
| RED | passed on the reference; mere-ruby ran it and it failed, errored or skipped |
| MISSING | passed on the reference; absent from mere-ruby's output (it stopped, crashed or hit a bound first) |
| UNCONFIRMED | passed on the reference; `.` in a mere-ruby transcript whose lines and summary disagree (COUNT_MISMATCH, REPORT_MISMATCH). Not a MATCH |
| BOTH | did not pass on the reference (failure, error or skip). Not in the denominator |
| EXTRA | only in mere-ruby's output |

Each side's file also gets a state: COMPLETE, INCOMPLETE (no summary line),
WALL_LIMIT, MEMORY_LIMIT, ZERO, COUNT_MISMATCH (including a name reported
twice, which keeps its worse verdict), REPORT_MISMATCH, or EXIT_ERROR (a
summary, but an exit that is not minitest's 0 or 1 for it: a signal after the
summary). A file whose reference is not COMPLETE is `REFERENCE_<state>`, and
nothing in it is compared. A partial or EXIT_ERROR mere-ruby transcript keeps
the verdicts it did report.

`same_order` says whether the two sides ran their common tests in the same
order. The same `--seed` is not enough: anything that draws random numbers
between the shuffle's draws changes it. A file where it is false may have
results that depend on order. A result line is read from the start of the
line, so a class name with spaces (a `describe` block) is kept whole. A test
that prints to stdout without a newline puts that output in front of its own
result line. The name read then carries the output, and the test shows as
MISSING on one side and EXTRA on the other (unless both sides print it the
same way). It is never counted as a MATCH that did not happen.

## Use

```sh
# 1. archives (the only network step)
python3 railstest/framework/run.py restore --archives /path/to/fw-archives

# 2. each side installs into its own empty gem home (either side may be redone alone)
python3 railstest/framework/run.py install --archives /path/to/fw-archives \
  --reference /path/to/ruby-4.0.9/bin/ruby --binary ./mere-ruby \
  --source /path/to/rails-v8.1.4.1 --sqlite-prefix /path/to/sqlite --output /path/to/fw-gems

# 3. run files or directories, relative to the Rails checkout
python3 railstest/framework/run.py run --jobs 2 \
  --reference /path/to/ruby-4.0.9/bin/ruby --binary ./mere-ruby \
  --source /path/to/rails-v8.1.4.1 --gems /path/to/fw-gems --output /path/to/new-run \
  activesupport/test
# (a component's own settings, the same on both sides and recorded:
#  `--env ARCONN=sqlite3 activerecord/test/cases`)

# 4. what changed between two runs, file by file (exit 1 when a MATCH is lost,
#    including a file or a mere-ruby side that is gone from the new record)
python3 railstest/framework/run.py compare --base old/results.json --new new/results.json
```

`check.py` holds the harness's own controls, which CI runs. They check that a
missing, failed, duplicated or unconfirmed test never becomes MATCH, that a
resource stop wins over a summary, that a crash after the summary is visible,
that an unhealthy reference compares nothing, that one side never runs two
files at once, that a vanished file fails `compare`, that foreign settings
are dropped, and that `--env` reaches both sides and refuses a runner
setting, a secret or a local path.

## Records

`records/` keeps the result JSON of each recorded run. These files hold no
local paths. Raw logs stay outside the repository.

- `install-c521aa58.json`: both sides' installation from the archives.
  Reference: 505.6 s, peak 1.86 GB. mere-ruby: 405.3 s, peak 716 MB.
  Both passed, and the twelve components' `lib/` match the tag.
- `activesupport-4files-d8f45207.json`: OrderedOptions, Concern, Inflector
  and ClassAttribute, at this branch's `d8f45207` (main `ab350da1`'s runtime).
  **539 MATCH / 2 RED / 0 MISSING / 0 UNCONFIRMED / 0 BOTH** of 541. The two
  RED tests are `InflectorTest#test_titleize_mixture_to_title_case_15` and
  `_21`. This is the same result as the earlier one-off comparison with each
  side's application gem home. `inflector_test.rb` is `same_order: false`:
  the same 473 names run in a different order from the second test on. The
  other three files run in the same order.
