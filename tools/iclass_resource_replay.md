# Replay the original iclass timeout

The hosted PR115 failure at source `c22ad346` times out in the original
`TestModule#test_iclass_memory_leak` and complemented-entry children. The
complete file discovers195 cases; neither failure is an outer2-GiB event.
The test-merge tree is identical to published head `767c7690`.

The independent `iclass-resource-replay.yml` job locks that exact failed
source, Ruby source `3e93b23a`, parent compiler43f2994b and published
Map-slot repair408b03d9 on one native Linux/x86-64 runner. It builds both
ordinary O2 binaries before measurement. Reversing only32 Map clear and32
delete fragments must restore the parent's generated C exactly.

The fixed selected-case order is reference / parent / repair / repair / parent,
followed by the complete original Module file on all three interpreters and
one paired original Method-copy check per compiler. Each selected child keeps
its original1,000 warmup and3,000,000 measured iterations, arguments, waiting,
termination behavior and ten-second upstream bound. The parent observer only
saves stdin and returned stderr, rethrowing the original exception if needed.
Scaled upstream timeouts are rejected. Only the upstream nonce is normalized
before comparing the pinned child-input SHA. No collection, sleep, allocation
policy, cache tuning, skipped case or retry-until-pass loop is added.

A small Python wait4 wrapper records real user/system CPU usage of the selected
Ruby parent and waited descendants. It preserves the exit status and does not
measure the child body in isolation. The outer600-second /2-GiB family guard
also includes this wrapper. Logs, CPU observations, original stdin, complete
case dictionaries, every Method-copy prefix and all exits are retained even
on failure. A failed reference or repair remains failed; a failing parent is
retained evidence rather than a requirement to pass before a repair is tested.

The retained Linux/aarch64 capture passes both compilers: parent5.929 /6.094s,
repair5.945 /6.198s. CPU usage is close to elapsed time. It does not reproduce
the hosted x86-64 timeout and does not establish a speed improvement. A separate
end-to-end validation of the published runner passes with parent6.132 /6.151s
and repair5.943 /6.035s; it is retained separately rather than replacing the
first observations. Complete Module195/1240 and the original Method-copy also
pass. Native x86-64 evidence is required before assigning the timeout's cause.

Run `python3 tools/iclass_resource_replay.py` with `--before`, `--repair`,
`--before-compiler`, `--repair-compiler`, `--ruby-src`, `--reference` and
`--output` paths. All source/compiler refs, ordinary O2 modes, original test
hashes and resource bounds are verified. The11 acceptance checks reject
altered input, expanded timeout, omitted trial/case/prefix, missing CPU data,
and forged success flags. Existing historical jobs, pins and snapshots are
unchanged. This adds a measurement, not a claim that iclass has been repaired.
