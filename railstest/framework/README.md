# Rails' own component tests, file by file

This runs the test files of Rails 8.1.4.1 itself (`activesupport/test`,
`activemodel/test`, ...) on the reference Ruby 4.0.10 and on mere-ruby, and
compares them test by test. It is the measurement for the framework half of
the Rails plan. The application in `railstest/app` is measured separately by
`railstest/measure.py`.

## What is fixed

- **Rails source**: tag `v8.1.4.1` (`3f290b759c8e2ffe7c257951b1255740751355e4`).
  `run` refuses another commit or a checkout with local changes. Each side
  gets its own copy of the tagged tree (`git archive`), because tests write
  beside themselves and the two sides run at the same time.
- **Gems**: `Gemfile` and `Gemfile.lock` hold the published Rails gems,
  sqlite3, minitest, and test-only gems. The original test-only gems are
  minitest-mock, rexml, rack-cache, bcrypt and msgpack, at the versions in
  Rails' own lock. minitest (6.1.0) and sqlite3 (2.10.2) are the
  application's locked versions, not Rails' (6.0.6 and 2.9.4). One lock for
  both measurements keeps one set of native builds to trust, and Rails 8.1.4.1
  accepts both. The lock was made from the application's lock with
  `bundle lock --conservative`. That drops puma and adds the five gems.
  Action Pack also needs Capybara 3.40.0, Dalli 4.3.3, Launchy 3.1.1 and
  Selenium WebDriver 4.44.0. These direct versions, and the RubyZip 2.4.1
  constraint, come from Rails' lock. Their transitive dependencies were
  resolved conservatively, preserving every previously locked package.
  Active Support's file-watcher tests add Listen 3.10.0, at Rails' locked
  version, with rb-fsevent, rb-inotify and ffi.
  `archives.lock.json` pins all 89 archives with their SHA-256.
  When updating from an earlier lock (73 or 85 archives), run `restore` again before
  `install`. Existing archive bytes are reused; the new locked inventory must
  be complete and contain no extra archives.
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

By default both sides use the application bootstrap (`../bootstrap.rb`),
with their own gem home and Bundler, and a scrubbed environment. mere-ruby is
also given the reference standard library on `RUBYLIB`, as in `../README.md`.
That is how mere-ruby sees default gem specs. The reference is not.

Action Pack needs `--framework-bootstrap`: this opt-in startup loads the
reference standard library's unmodified `bundled_gems`, `did_you_mean` and
`error_highlight`, restoring libraries suppressed by `--disable-gems`.
Other components retain their existing startup unless the flag is supplied.
The flag and the selected bootstrap's hash are recorded in `results.json`.
Installation always keeps the application bootstrap.

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

Test names are compared literally by default. A parameterized test may put
an anonymous class address in its name, which differs between processes.
`run --case-identity-policy opaque-class-addresses` explicitly permits pairing
unique `#<Class:0x...>` descriptions. Both inventories must be COMPLETE;
ambiguous shapes and inconsistent address relationships remain unmatched.
Raw case names stay in `sides`, accepted mappings are recorded as
`case_identity_aliases`, and the selected policy is recorded at the top level.
Failures, skips, extra tests and incomplete runs retain their original meaning.
`compare` requires the same identity policy in both records. With the opaque
policy it also pairs their COMPLETE reference inventories, so changed process
addresses cannot conceal a lost MATCH. Ambiguities still fail conservatively.

`rails-argument-descriptions` additionally pairs the three current-clock Range
descriptions in Rails 8.1.4.1's unchanged `argument_serialization_test.rb`.
Its source SHA-256 must match the runner's pin; changed or unknown sources
retain literal clock names. Each description must be unique on both COMPLETE
inventories. Endpoint UTC offsets, test types and range forms remain part of
the identity. Assertions run unchanged; a paired failure remains RED. Both
original names and accepted aliases remain available in the record. The
existing policies retain their behavior.

Before discarding clock text, each side must independently describe the
expected interval: ten calendar days to Date.today (allowing a two-second
midnight crossing), ten elapsed hours, or four elapsed weeks (two-second
tolerance for separate clock reads). DateTime weekdays and Date's printed
Julian day must agree with the calendar date. Invalid dates, offsets or
intervals retain literal identities. Subsecond precision may vary.

ActiveJob's `exceptions_test.rb` eagerly loads SneakersAdapter even when using
a built-in adapter. Its real gem dependencies are locked here; no RabbitMQ
worker is started. Run that file with `--env AJ_ADAPTER=test` to exercise its
scheduling tests: inline skips the entire test class. `continuation_test.rb`
also needs test, and `async_adapter_test.rb` needs async. Keep the disjoint
adapter cohorts and their environments visible when reporting a component.


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
same way). It is never counted as a MATCH that did not happen. A test logger may put
lines between minitest's name prefix and its duration/verdict; the parser
keeps that explicit name pending until its result arrives. An orphan result
or a missing verdict still fails the transcript count checks.

## Use

```sh
# 1. archives (the only network step)
python3 railstest/framework/run.py restore --archives /path/to/fw-archives

# 2. each side installs into its own empty gem home (either side may be redone alone)
python3 railstest/framework/run.py install --archives /path/to/fw-archives \
  --reference /path/to/ruby-4.0.10/bin/ruby --binary ./mere-ruby \
  --source /path/to/rails-v8.1.4.1 --sqlite-prefix /path/to/sqlite --output /path/to/fw-gems

# 3. run files or directories, relative to the Rails checkout
python3 railstest/framework/run.py run --jobs 2 \
  --reference /path/to/ruby-4.0.10/bin/ruby --binary ./mere-ruby \
  --source /path/to/rails-v8.1.4.1 --gems /path/to/fw-gems --output /path/to/new-run \
  activesupport/test
# (a component's own settings, the same on both sides and recorded:
#  `--env ARCONN=sqlite3 activerecord/test/cases`)

# 4. what changed between two runs, file by file (exit 1 when a MATCH is lost,
#    including a file or a mere-ruby side that is gone from the new record)
python3 railstest/framework/run.py compare --base old/results.json --new new/results.json
```

For all 173 Action Pack files, start a local memcached server (the upstream
MemCacheStore tests otherwise omit their test methods), then run:

```sh
python3 railstest/framework/run.py run --jobs 2 --require-all-pass --framework-bootstrap \
  --reference /path/to/ruby-4.0.10/bin/ruby --binary ./mere-ruby \
  --source /path/to/rails-v8.1.4.1 --gems /path/to/fw-gems --output /path/to/new-run \
  --env MT_CPU=0 --env MEMCACHE_SERVERS=127.0.0.1:21347 actionpack/test
```

`MT_CPU=0` uses Rails' supported serial test execution on both sides; the
runner still runs the two interpreters concurrently. `--require-all-pass`
is a strict gate: every selected file must complete on both interpreters,
with the same test inventory and no failures, errors or skips.
Only the two known upstream files without runnable tests are recorded as EMPTY
with zero MATCH: controller/new_base/render_xml_test.rb and the zero-byte
journey/nodes/symbol_test.rb. Their source sizes and SHA-256 digests must match
the locked tag. Other zero-run files fail the gate, including a MemCacheStore
file that omits its methods because memcached is unavailable. Missing files, tests,
unusable references and resource stops exit 1. Without
this option the runner retains its original measurement-only exit behavior.
The selected file inventory and gate setting are recorded in `results.json`.
The frozen 8624fb60 evaluator measurement accounts for all 173 files with
4,152 MATCH and no RED, recorded in
`records/actionpack-full-8624fb60.json`. Later builds need their own validation.

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

- `actionpack-integrated-summary.json`: 26 focused Action Pack files, 1091 MATCH,
  two C API-owned RED and two verified EMPTY files. It links all six native
  batch records. The matching runtime's complete corpus has 887/887 matches
  with both hash modes; its VM corpus has 883 VM / 4 fallback / zero differences.
  `actionpack-integrated-rss.json` compares two large files against main 976bb95d.
  Full 173-file validation and fresh native installation passed on frozen
  build 8624fb60 (4,152 MATCH); later builds need separate validation;
  see `actionpack-plan.json` and the dated Action Pack loop record.
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
- `activesupport-8bf5563b.json`: all of `activesupport/test` (170 files) at
  `8bf5563b`, the first round of the ActiveSupport work (#181).
  **4,675 MATCH / 63 RED / 1 MISSING / 29 BOTH**. 8 files are not compared,
  because the reference does not complete them here. Three cache files
  require `dalli` or `redis`, which are not in the lock. Four `xml_mini`
  engines run no test (JDOM is JRuby's, and LibXML needs `libxml-ruby`), and
  the reference's `event_reporter_assertions_test.rb` prints no summary.
- `install-68588737.json`: the gem home the two `68588737` records ran in.
  mere-ruby's side was installed again by that build (320.8 s, peak 1.74 GB).
  The twelve components' `lib/` match the tag. The reference's side is the one
  in `install-c521aa58.json`, kept as it was.
- `activesupport-68588737.json`: all 170 files at `68588737`, which is
  main `03c2869a`'s runtime. **4,546 MATCH / 34 RED / 159 MISSING / 29
  BOTH**. 158 of the MISSING are `json/encoding_test.rb`, which stopped
  before its first test at `require "bundler/setup"` ("Your bundle only
  supports platforms []"). String#split with a block lost its pieces to a
  collection, and Bundler's lockfile parser read no PLATFORMS. #195 fixes
  that, and the file then runs 158 MATCH. Against `8bf5563b`, that file is the only
  one that lost a MATCH. Eight files gained: `backtrace_cleaner` (+8),
  `time_travel` (+5), `safe_buffer` (+4), the two MessagePack serializers
  (+2 each), `string_inquirer` (+2), `array_inquirer` and `string_ext` (+1
  each).
- `activesupport-68588737-vm.json`: the same build and files with
  `--mere-env MERE_RUBY_VM=1`. **4,667 MATCH / 31 RED / 41 MISSING / 29
  BOTH**. The 31 RED are the evaluator's 34 without `error_reporter` (1) and
  `deep_mergeable` (2). 40 of the MISSING are `xml_mini/nokogiri_engine_test.rb`
  and `nokogirisax_engine_test.rb`: requiring nokogiri stops on the VM with
  `Nokogiri::HTML is not a module`. The evaluator runs both files.
- `actionpack-full-8624fb60.json`: all 173 Action Pack files on frozen build
  `8624fb60` with `--require-all-pass` (see "Use" above): **4,152 MATCH**, no
  RED, MISSING or BOTH, two EMPTY files. `actionpack-full-8624fb60-validation.json`
  holds that build's provenance, its fresh native installation and the corpus
  run after it.
- `actionpack-reference-4.0.10.json`: the reference Ruby 4.0.10 installation
  the Action Pack records ran against, and the gem specifications inside it.
- `actionview-*`, `activemodel-*`, `activesupport-*` and `actionmailer-*`
  records named after a change (`actionview-struct-keyword.json`,
  `activesupport-zlib-fast-insertion.json`, ...) are the evidence of one fix
  each, all against Ruby 4.0.10: the runtime commit and the one it is
  compared with, the corpus in both hash modes and on the VM, the source
  gates, the related CRuby test files, and the Rails files the change was
  for, run before and after. They are not whole-component measurements,
  except where a record says so:
  - `actionview-struct-keyword.json` (`actionview_baseline_context`): all
    64 Action View files on runtime `63213030` (2026-11-26, not a main
    commit). Evaluator **3,155 MATCH / 48 RED / 0 MISSING / 2 BOTH**; VM
    3,157 / 46 / 0 / 2.
  - `actionmailer-singleton-class-super.json` (`full_actionmailer`): all 17
    Action Mailer files, on the evaluator and on the VM alike. On runtime
    `85d7500b` every file stopped before its tests (268 MISSING); with the
    change, on integration runtime `d1ce15ee` (main `491cc5ca` and the
    changes the record names, 2026-11-28), **248 MATCH / 20 RED**.
  - `activemodel-*` records carry the 58-file Active Model baseline they
    started from (`component_baseline_context`), with the causes of its RED
    grouped.
