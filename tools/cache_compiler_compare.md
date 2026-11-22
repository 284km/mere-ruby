# Compare cached payload clearing without replacing the RSS gates

`cache_compiler_compare.py` compares ordinary O2 binaries made from the same
locked runtime. The default is the repaired method-floor source
`90c83c6e525fbac7c7b9cdf670bd5e6db1ca79a5`. A second locked choice,
`ae6bd8cc89a98fc01a1e129d3becc447b637d35f`, is the actual historical source
used by the failing heap investigation. Select it with `--subject-ref`;
both binaries must use that exact source. The parent compiler
is `01f5ad738748cc570cc04e3000f50b8c6965543f`; the candidate compiler is
`94da60b51e438404edf857ed09941c5db8361dca` ([Mere PR #85](https://github.com/merelang/mere/pull/85)).
The candidate changes only how dead cached payload bytes are cleared on Linux.
Existing compiler pins in other jobs remain unchanged.

The independent `Cache compiler RSS comparison` matrix builds both compilers and
both binaries for each source on one native x86-64 runner per source. The collector checks clean locked
checkouts, ordinary O2 mode, binary and generated-C hashes, and that reversing
only the clearing helper and its call restores the parent's C exactly.
Keep the two runtime checkout directory names equally long (`before` / `repair`).

The Method-copy program runs in fixed parent / candidate / candidate / parent
order, with a reference run for each. Every collected prefix counts toward the
existing 2x growth bound; a later passing sample cannot hide an earlier failure.
Then the original full Module, selected clone and complemented-entry, and full
Refinement controls run on reference / parent / candidate. The selected child
inputs are hashed after normalizing only the upstream nonce. Case identities,
counts, summaries and previously passing cases must agree with the reference.
Original 600-second / 2-GiB process-family bounds and 10-second upstream child
limits remain in force. Diagnostic builds are not accepted as ordinary O2.

Raw logs, original child inputs, case transcripts, exit/limit records and hashes
are uploaded even on failure, in an artifact named `cache-compiler-native-<subject SHA>`.
Candidate or reference failures make the job fail;
a failing parent is retained as evidence rather than required to pass before
an improvement can be evaluated. The historical source retains its original
method-floor implementation: selecting it does not omit Method-copy or waive a
failed prefix. This job does not update accepted baselines or change the
compiler/subject pins in the existing heap investigation.

`tools/fixtures/cache_compiler_failure.json` captures the first Linux/aarch64
comparison: the candidate's Method-copy ratio was 2.080805 in one run, despite
the selected clone improving from 1.677594 to 1.395957. This is failed evidence,
not an accepted fix for all RSS failures. The acceptance checks replay it and
reject forged success flags, altered ratios/bounds, missing prefixes or cases,
and modified upstream child inputs.

Run acceptance checks with `python3 tools/cache_compiler_compare_check.py -v`.
The workflow contains the complete build and collection commands. All original
test files and programs are retained; the collector does not insert GC calls,
change warmup, adjust cache/pinning policies, or waive a failed assertion.
