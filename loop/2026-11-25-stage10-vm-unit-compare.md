# CRuby's tests on the evaluator and on the ISeq VM, compared test by test

#232's fourth proposal, as the owner decided: a script in `unittest/` that compares the two executions test by test, and a scheduled job that runs it.

## The script

`sh unittest/vm_compare.sh <ruby-src> [--list FILE] [path under test/ ...]`

It runs `unittest/run.sh` twice over the files, once with MERE_RUBY_VM unset and once with MERE_RUBY_VM=1, each into a record of its own (`UNITTEST_RECORD_DIR`). Each run is run.sh's as it is: the file under ruby and under mere-ruby, and a tag of each test mere-ruby did not pass. `unittest/vm_compare.py` then compares the two records:

| | |
|---|---|
| VM_ONLY | a test the evaluator passed and the VM did not |
| EVAL_ONLY | a test the VM passed and the evaluator did not |
| VM_FILE | a file the evaluator completed and the VM did not |

A test the same build passes the other way is the VM's to answer for, so no baseline is needed: the evaluator is the baseline. Ruby is asked only what run.sh already asks it.

**A difference is counted when it is seen twice.** The files in which the two differ are run once more on both executions, and only what differs both times is reported. On the first local run below, three tests differed; two of them were time limits under a load of 30 (test_exception's `test_blocking_backtrace`, which has a 10 s bound, and test_syntax's `test_invalid_symbol_in_hash_memory_leak`) and did not differ the second time.

It exits 1 when a VM_ONLY or a VM_FILE remains.

## The job

`unittest-vm` in `ci.yml`, on the weekly schedule and by hand (`workflow_dispatch`) only: it is two runs of the files on each side. It is set up as the unit-test shards are (the reference runtime, CRuby's test extensions built against mere-ruby's C API) and runs the script over `unittest/vm_compare_files.txt`, uploading the records.

The files are the 22 that rounds 60 to 65 compared by hand: test_require, test_autoload, test_parse, test_syntax, test_iseq, test_eval, test_regexp, test_rubyoptions, test_exception, test_backtrace, test_m17n, test_symbol, test_encoding, test_literal, test_hash, test_pattern_matching, test_compile_prism, test_ractor, test_transcode, test_mixed_unicode_escapes, and enc/'s test_shift_jis and test_euc_jp. The aim is test/ruby whole, when its time has been measured (after the Codex session's actionpack run, as agreed).

It runs run.sh directly, not through `unittest/ci.py`, whose shards check a measurement plan and give each side an emptied environment. Both executions get the same environment here, which is what the comparison needs; the records are not the shards' and are not merged into STATUS.md.

## The first run

Locally, against ruby 4.0.10, on main 9d1948f8, at a load of 30:

```
vm_compare: 22 files -- VM_ONLY 0, EVAL_ONLY 1, VM_FILE 0
```

1,712 tests; 39 minutes in all (the evaluator's pass 19, the VM's 17, the second run of three files 4). The one EVAL_ONLY is test_parse's `test_method_location_in_rescue`, which the VM passes and the evaluator does not (a method's source location under a rescue).

## Checked

- The script's exit: 0 on the run above; 1 with a VM-only failure written into the VM's record by hand.
- `ci.yml` parses (the new job: two needs, nine steps). The job has not run in CI: it runs only on the schedule or by hand.
