# CI compares every corpus program on the ISeq VM as well

#192 found a defect that only the VM had: a `def` inside module_eval was defined in the wrong place (vm_cls_stmt took self as the definee only when it was a VClass). CI ran the corpus on the evaluator alone (`run_corpus.sh --both`), so it could not see that. Every PR so far ran `tools/iseq/vm_corpus.sh` by hand, and note 558's merge rule now asks for it (aidocs f089eeea).

Both corpus jobs now run it, right after the evaluator's:
- macOS, `sh tools/iseq/vm_corpus.sh -j 3`;
- Linux, `sh tools/iseq/vm_corpus.sh -j 2` under the same stack limit.

The script runs each program with MERE_RUBY_VM=1 and compares its output and exit status with the reference ruby's. It exits non-zero on a difference. A program the VM declines runs on the evaluator and is counted as fallen back, not as failed. Locally, on main 03c2869a, it gives 838 programs: 834 on the VM, 4 fallen back, 0 different.

This is a step toward making the VM the default execution: until then, the VM's correctness has a gate of its own.

**Not checked locally:** the Linux run. This PR's CI is its first run there.
