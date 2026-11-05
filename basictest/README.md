# Basic measurement

`measure.py` runs the pinned, unmodified `basictest/runner.rb` under the exact
native reference Ruby. The runner's `RUBY` launcher invokes either the reference
or O2 mere-ruby on the original `basictest/test.rb`. Its `./miniruby` CLI children
use the same selected binary. Each side gets a private work directory, HOME
and TMPDIR, a 600 second process-family wall bound and a 2 GiB RSS bound.

The upstream runner discards successful body output. The launcher therefore
persists the body's stdout and final exit status before forwarding stdout to
that runner. Assertions, expected values and source lines are unchanged. A
private source symlink avoids the upstream runner's unquoted shell source path.
PATH and env-shebang Ruby children use the selected side too.

Case identities are original source line plus occurrence. The body's `ok` and
`not ok` records, final test/failure counts, body exit and runner exit must
agree. The final failure summary is a completed measurement with failed cases;
missing final output, malformed records, a crash after the summary and a
resource limit cannot turn progress into passing cases. Zero cases remain ZERO.
Only a complete native reference makes this measurement job succeed. Mere's
behavior differences and incomplete execution stay visible in the report.

`basic-report` contains JSON case observations and effective verdicts, both
sides' sanitized body/runner output and a Markdown summary. It records the
same plan, compiler, source and exact binary provenance as the unittest and
bootstrap jobs, plus the upstream body/runner and harness hashes. These totals
are separate from `unittest-report` and `bootstrap-report`.

```sh
python3 basictest/measure.py --ruby-src .ruby-tests \
  --plan measurement-plan/manifest.json --suites measurement-plan/suites.json \
  --build-info build-info.json --reference-info reference-build.json \
  --binary mere-ruby --reference .reference-ruby/bin/ruby --output basic-report
```

For parser and real native-host checks:

```sh
UNITTEST_REAL_RUBY=/absolute/path/to/ruby \
UNITTEST_BASIC_RUNNER=/absolute/path/to/ruby-source/basictest/runner.rb \
python3 basictest/measure_check.py -v
```
