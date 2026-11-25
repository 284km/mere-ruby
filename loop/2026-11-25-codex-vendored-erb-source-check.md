# Compare the renamed vendored ERB source with its actual upstream path

## Cause and change

Linux build CI stops in headers_check before runtime gates: the vendored
ERB source is named erb_escape.c, but Ruby keeps it at
ext/erb/escape/escape.c. The checker assumed every vendor-relative path was
also the upstream-relative path. This failure also reproduces on main.

List that rename explicitly and continue comparing every byte. Ordinary
vendor paths retain their existing rule; a missing or modified renamed
source still fails. Vendored bytes and runtime source are unchanged.

## Validation and review integration

The original checker fails against clean Ruby 4.0.10 source. The corrected
checker passes: 194 headers, ten explicitly patched headers and 21 unchanged
vendored sources. Scratch copies reject modified ERB bytes and a missing
upstream file, even with an old-location same-basename decoy. Restoring the
explicit upstream file passes.

The reviewer independently reproduced that result. Main has since added
unittest-vm to the CI timing report in PR 275. Merge main 0cd831f0 and keep
its workflow byte for byte, resolving the overlapping needs-list edits. The
final diff against that main contains only the checker and this record;
there is no workflow or runtime change. Run the timing self-tests, all source
gates and record_hygiene before the batched follow-up push, then read inline
comments again. Historical full-corpus and RSS results belong to head
81b3001d and are identified separately in the PR description; do not label
them final-head measurements. The reviewer requests checker/gate validation
for this source-check-only integration, without another full corpus sweep.

No upstream unit file changes, full unit suite or Rails cold measurement.
