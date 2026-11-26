# Framework watcher test dependencies

The framework lock omitted `listen`, so 27 ActiveSupport watcher cases failed on both
interpreters before reaching their assertions. Add Rails' locked listen 3.10.0 plus ffi
1.17.4, rb-fsevent 0.11.2 and rb-inotify 0.11.1; archive lock grows from 85 to 89
without changing existing package versions/checksums. No runtime or shared runner logic
changes.

Resolved offline with pinned Bundler 4.0.20 and verified downloaded archive SHA-256
digests against RubyGems metadata. Fresh native installation of all 89 packages succeeds
on both interpreters, using measured integration 6facff83 (same binary for install and
replay). The clean reference is Ruby 4.0.10 via `tools/ref_ruby.sh`, revision
a704b7cd95a42cc0cf5f307137bf3aac0285b915, no extra gems, Prism 1.8.2. Gems are installed
in owned output directories.

Validation:

- Framework harness: 27 tests pass, including archive/lock checks.
- Both full watcher files are COMPLETE on reference and Mere, on evaluator and VM, with
comparison main a232 and integration 6fac: 47 MATCH / 1 RED / 0 BOTH, no
MISSING/UNCONFIRMED/EXTRA. Of 27 previously unexecuted cases, 26 now pass. The remaining
`test_can_be_garbage_collected` fails on both comparison builds/engines and is reported
as an existing GC mismatch; no all-pass claim.
- Measuring runtime 6fac's corpus --both passes 959/959; VM corpus 959 VM / 0 fallback /
0 differences, with source gates and default hygiene. This is explicitly existing
runtime-control evidence, not a fresh runtime build of this metadata-only branch. No
interpreter source changed. Explicit new-record hygiene is checked separately.
- Bounds remain 600 s / 2 GiB, jobs 2, MT_CPU=0. Native platform validation is Darwin
arm64; no Linux native-build claim.

Peak family RSS, KiB, single samples (no stable memory comparison claimed):

| File | main evaluator | main VM | integration evaluator | integration VM |
| --- | --- | --- | --- | --- |
| evented_file_update_checker_test.rb | 427904 | 448256 | 424960 | 458352 |
| file_update_checker_test.rb | 371104 | 338192 | 316144 | 338544 |

Evidence: `loop/2026-11-26-codex-rails1-listen-test-dependencies.md` and
`railstest/framework/records/activesupport-listen-test-dependencies.json`.
