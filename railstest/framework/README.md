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
  sqlite3, minitest 6.1.0, and five test-only gems. The test-only gems are
  minitest-mock, rexml, rack-cache, bcrypt and msgpack, at the versions in
  Rails' own lock. The lock was made from the application's lock with
  `bundle lock --conservative`. That drops puma and adds the five gems.
  `archives.lock.json` pins all 73 archives with their SHA-256.
  Rails' own Gemfile is not used: it pulls in external-service gems
  (mysql, redis, selenium, ...) and documentation tools.
- **Component code**: the tests take `lib/` from the installed component gems.
  `install` checks that every installed component's `lib/` is byte-identical
  to the tagged source's `lib/`, and fails otherwise.
- **Bounds**: each file runs under the same 600-second / 2-GiB process-family
  bounds as the rest of the project. **At most two processes run at a time**
  (`--jobs` is 1 or 2): the machine is shared.

## Environment

Both sides use the application measurement's bootstrap (`../bootstrap.rb`),
with their own gem home and Bundler, and a scrubbed environment. mere-ruby is
also given the reference standard library on `RUBYLIB`, as in `../README.md`.
That is how mere-ruby sees default gem specs. The reference is not.

A file runs as Rails' Rakefile runs it, from the component directory:

    ruby -w -Itest test/<file> -v --seed 12345

`RAILS_STRICT_WARNINGS`, `BUILDKITE` and `CI` are removed, so warnings are not
errors on either side.

## Verdicts

Each test name the reference reports gets one verdict:

| verdict | meaning |
|---|---|
| MATCH | passed on both sides |
| RED | passed on the reference; mere-ruby ran it and it failed, errored or skipped |
| MISSING | passed on the reference; absent from mere-ruby's output (it stopped, crashed or hit a bound first) |
| BOTH | did not pass on the reference (failure, error or skip). Not in the denominator |
| EXTRA | only in mere-ruby's output |

Each side's file also gets a state: COMPLETE, INCOMPLETE (no summary line),
WALL_LIMIT, MEMORY_LIMIT, ZERO, COUNT_MISMATCH or REPORT_MISMATCH. A file
whose reference is not COMPLETE is `REFERENCE_<state>`, and nothing in it is
compared. A partial mere-ruby transcript keeps the names it did report.

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

# 4. what changed between two runs, file by file (exit 1 when a MATCH is lost)
python3 railstest/framework/run.py compare --base old/results.json --new new/results.json
```

`check.py` holds the harness's own controls, which CI runs. They check that a
missing or failed test never becomes MATCH, that a resource stop wins over a
summary, that an unhealthy reference compares nothing, and that foreign
settings are dropped.

## Records

`records/` keeps the result JSON of each recorded run. These files hold no
local paths. Raw logs stay outside the repository.

- `install-c521aa58.json`: both sides' installation from the archives.
  Reference: 505.6 s, peak 1.86 GB. mere-ruby: 405.3 s, peak 716 MB.
  Both passed, and the twelve components' `lib/` match the tag.
- `activesupport-4files-c521aa58.json`: OrderedOptions, Concern, Inflector
  and ClassAttribute, on main `c521aa58` (the run's `source_ref` is this
  branch's work-in-progress commit, which adds only `railstest/` files on top
  of it). **539 MATCH / 2 RED / 0 MISSING / 0 BOTH** of 541. The two RED
  tests are `InflectorTest#test_titleize_mixture_to_title_case_15` and `_21`.
  This is the same result as the earlier one-off comparison with each side's
  application gem home.
