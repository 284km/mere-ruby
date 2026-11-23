# CI runs test_ast.rb as four units, each with a name filter, inside the same per-file bounds

**Why.** test_ast.rb took 582 s on the slowest CI runner against a 600 s per-file bound, so any slower day turned it into WALL_LIMIT. Round four and five looked for its time and found it in the evaluator's frame representation: a string-keyed table holds the locals and the frame's own facts. That is a redesign shared with the VM (work2026-49), weeks of work. The decision (note 558, through work2026-fd) is to run the file in parts. The bounds are not relaxed: each part is held to 600 s and 2 GiB on its own, as a file is.

**The split** (`unittest/splits.tsv`). There are four parts by test name:

| part | filter | tests |
|---|---|---|
| 1 | `/#test_all_tokens:test\/ruby\//` | 200 |
| 2 | `/#test_all_tokens:(?!test\/ruby\/)/` | 650 |
| 3 | `/#test_ranges:/` | 850 |
| 4 | `!/#test_(?:all_tokens|ranges):/` (everything else: test_not_cared and the named tests) | 964 |

The last part is the negation of the others, so every test runs in exactly one part, including any test added later that the others do not name. Locally the parts take 133, 121, 119 and 74 s of the file's 447 s. Scaled to the slowest runner, that is about 172, 158, 154 and 97 s, well under half the bound each.

**The mechanism.**

- **`list.sh`** lists `<file>@<part>` for every row of `splits.tsv`, in place of the file. It does so in every mode, and passes the list through unchanged when the table is absent.
- **`run.sh --one`** takes a unit `<file>@<part>`.
  - The file's path, load path, preloads (`UNITTEST_TEST_FILE`) and directory all come from the file part.
  - Both sides get `-n <filter>`.
  - Logs, the tag and the coverage row keep the part (`ruby_test_ast@3.out`).
  - A part the table does not have is refused rather than run unfiltered.
- **`ci.py`** names logs and tags with `log_key`, which keeps the part. It was `file[:-3]`, which assumed the name ended in `.rb`.
- **`timings.json`** has an estimate for each part, so the scheduler places them.
- **`harness_check.py`** copies `splits.tsv` into its fixture. A new check covers the listing, the filter reaching both sides, the names, and the refusal of an unknown part.

**The totals are the same.** The file was run whole, and part by part, with `run.sh --one` (main 94aa899b's binary). The sums of tests, MATCH, RED, BOTH and EXTRA are below. `merge` adds rows, so the summary's totals are unchanged. Its `expected_files` grows by three, because one file became four units.

| run | tests | MATCH | RED | BOTH | EXTRA |
|---|---|---|---|---|---|
| `ruby/test_ast.rb` whole | 2664 | 2651 | 0 | 13 | 0 |
| parts 1–4 summed (200 + 650 + 850 + 964) | 2664 | 2651 | 0 | 13 | 0 |

The test names match as well: on both sides, the union of the four parts' cases is the whole file's set, and no name appears in two parts.

**Other consumers of the list.** `suite_inventory.py` hashes the listed files, so it maps a unit back to its file and drops the duplicates. It still counts 758 test files.

## Review of #186

- **The complement.** Part 2 read `test_all_tokens:test/(?!ruby/)`, so parts 1 and 2 together covered only names under `test/`, while part 4 left out every `test_all_tokens`. A name with another prefix would have run nowhere. Part 2 is now `test_all_tokens:(?!test/ruby/)`: parts 1 and 2 are exactly what part 4 leaves out. Against the whole file's 2,664 names, every name matches exactly one part, and the counts are unchanged (200 / 650 / 850 / 964).
- **The table is checked.** `list.sh` refuses, with exit 2, a row that is not three columns, parts out of order, a negation before the last part, a file without a final negation, and a file the tree does not have. The harness fixture writes its own table, and a check covers each refusal.
- **README.** `unittest/README.md` says what a split is and how its results read: sum the parts to compare with a round from before the split, and an upstream exclusion is counted once per part.
