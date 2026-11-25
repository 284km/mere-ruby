# Action Pack full run after the append-flush correction

All 173 selected Action Pack files are accounted for: **4,152 MATCH**,
zero RED / MISSING / BOTH / UNCONFIRMED / EXTRA, and zero execution-order
differences. The optional strict all-pass gate exits 0.

The O2 build is `8624fb60c61a2b06f9e241b81a4c988cd59e2fac`, on
`codex-actionpack-full-20261125`: main `66a7afd0` (#235), the runtime and
framework changes from #228, and the independently submitted #237 / #238
SQLite and IO.console fixes. The Mere compiler is
`9dec2ff687a08433247dbdb7729bc19c8522e538`. Native gems were installed afresh
with exactly the measured binary, whose SHA-256 is in the records.

The reference is clean Ruby 4.0.10, revision
`a704b7cd95a42cc0cf5f307137bf3aac0285b915`: 84 default/bundled specifications,
zero extra gems, default Prism 1.8.2. The previously committed reference
manifest and gem list identify the same binary. Rails source is the unchanged
8.1.4.1 tag, `3f290b759c8e2ffe7c257951b1255740751355e4`.

Installation began at 2026-11-24T22:37:09.284241Z and finished at
22:54:26.161552Z. The full run began at 22:54:26.214364Z and ended at
23:51:41.598340Z, all UTC. Seed 12345, `MT_CPU=0`, `--jobs 2`, and the
existing 600-second / 2-GiB per-file-family limits were retained.

| Side | COMPLETE | ZERO | INCOMPLETE | COUNT_MISMATCH | MEMORY_LIMIT | WALL_LIMIT |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| reference | 171 | 1 | 1 | 0 | 0 | 0 |
| mere | 171 | 1 | 1 | 0 | 0 | 0 |

The ZERO is `controller/new_base/render_xml_test.rb`. The INCOMPLETE state
belongs to the zero-byte `journey/nodes/symbol_test.rb`: its zero-case, clean
exit is verified against the locked source identity and classified EMPTY.
Both sides have the same two EMPTY files. REPORT_MISMATCH is also zero.
No file hit either resource limit, so there are no standalone resource reruns.

There are no REDs to group by cause in this evaluator cohort. Routing
Inspector's previously diagnosed IO.console errors are cleared by #238.
Per-fix VM checks are recorded separately from this full evaluator run.

The full record retains both sides' test identities, per-file states,
summaries, counts, elapsed times and maximum process-family RSS:
`railstest/framework/records/actionpack-full-8624fb60.json`.
The accompanying `-validation.json` records timestamps, every state count,
fresh native-install provenance, the reference revision and the record digest.

The largest mere process-family peaks were 1,370,128 KiB for
`dispatch/debug_exceptions_test.rb` and 1,009,008 KiB for
`controller/show_exceptions_test.rb`. Earlier measurements with a growing
append-mode log predate #235 and are historical; this run supplies the valid
post-correction cohort. Focused before/after measurements are separate.

Completion and release of the shared heavy-run slot were posted to #228.
The next heavy run is work2026-df's complete unit-test run. The separate Linux
Module resource gate still has two 10-second child timeouts; the full Action
Pack result does not settle that CI failure.
