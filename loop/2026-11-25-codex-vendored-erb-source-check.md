# Keep CI integrity checks aligned with vendored sources and VM jobs

## Cause and change

Linux build CI stops in headers_check before any runtime gate: the vendored
ERB source is named erb_escape.c, but Ruby keeps it at
ext/erb/escape/escape.c. The checker assumed every vendor-relative path was
also the source-tree-relative path. The same failure reproduces on main.

List that rename explicitly and continue comparing every byte. All ordinary
vendor paths retain their existing rule; a missing or modified renamed
source still fails. No runtime source, vendored bytes or CI workflow changes.

## Validation

The original checker fails against the pinned clean Ruby 4.0.10 source;
the corrected checker passes: 194 headers, ten explicitly patched headers,
and 21 unchanged vendored sources. Scratch copies reject a modified
vendored ERB file and a missing upstream ERB file, even when an old-location
same-basename decoy exists. Restoring the explicit upstream file passes.
Run record_hygiene. Build the unchanged runtime in O2 and post source gates,
full corpus with both hash-index settings and VM/fallback/difference counts
before readiness. No unit-test file is changed and no full unit suite or
Rails cold measurement is run.

## Include the VM unit job in the integration report

The same main snapshot added unittest-vm without adding it to ci-timing's
needs list. The existing integrity self-test correctly fails: the report
must wait for every work job. Add that existing job to needs; preserve
always(), read-only actions/contents permissions, the Ubuntu runner and
artifact handling. This does not add a job or a workflow run.

The timing-check file reports 16 passes and one failure before the change;
rerun all 17 checks after the workflow dependency correction. Runtime source
and binary inputs remain unchanged. This workflow edit is for the repository
owner to merge, after final local validation. Batch this code and its record
in one follow-up push, only when local checks pass.
