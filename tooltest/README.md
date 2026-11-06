# CRuby tool tests

CI measures the pinned Ruby source's 12 `tool/test` candidate files in four
partitions. Each side runs the original `tool/test/runner.rb` on its own
interpreter and passes that interpreter to the upstream runner's `--ruby`.
CLI children, parallel fixtures and PATH-based `ruby` commands use the same
side. A private launcher handles interpreter paths containing spaces without
changing the upstream runner's argument parser.

`unittest/suite_inventory.py` inventories the candidate bodies and runner.
The measurement additionally hashes every Ruby file in `tool/test`, including
the `test4test_*`, `ptest_*`, init and parallel helper fixtures. Fixtures stay
owned by their original tests; they are not added as independent test bodies.

The `tool-report` artifact contains per-file and per-case outcomes, final
states, process-family resource limits, source and binary provenance, and
bounded diagnostic logs. Both interpreters use isolated environments and
temporary directories. A complete file can contain failures or skips;
MATCH/RED/BOTH/EXTRA record these separately from execution completion.

Rows are saved before starting either side and after each side. A missing
partition or a monitor error fails collection while retaining all planned
files and completed reference cases. A missing or interrupted Mere result
cannot turn a passing reference case into MATCH. Reference gaps also fail
the measurement, including successful zero-test executions.

The measurement does not implement missing Ruby features or count these 12
files as the complete set of upstream tests. Other suites have independent
inventories and runners.

Run the focused accounting and actual upstream-runner checks with:

```sh
UNITTEST_REAL_RUBY=/absolute/path/to/reference/ruby \
UNITTEST_TOOL_RUNNER=/absolute/path/to/ruby/tool/test/runner.rb \
  python3 tooltest/measure_check.py -v
```

`python3 tooltest/measure.py measure --help` lists the provenance and bounds
required for a local partition; `collect --input DIR --output DIR` collects
its `result.json` files.
