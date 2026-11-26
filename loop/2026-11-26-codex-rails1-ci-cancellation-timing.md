# Cancelled CI job timing

Keep CI timing reports available when GitHub cancels unassigned dependent jobs before
creating their job records. PR309's cancelled CI run45728827971 has nine jobs completed
at00:33:10Z but created at00:33:11Z; the reporter currently raises ValueError.

Report their queue delay as unknown with a specific reason, retaining raw timestamps and
cancellation conclusions. Real started executions and non-cancelled inverted timestamps
still fail. This changes the Python reporter and its controls only.

- All21 reporter controls pass, including the actual cancellation shape and two refusal
controls.
- Replay of the actual15-job cancelled run completes with9 unknown delays and444s summed
execution; the run remains unsuccessful.
- The second actual failure on PR315 (run45743632505) also replays successfully after
the fix:9 unknown delays,798s summed execution, cancellation remains unsuccessful.
- Archived22-job successful rerun is unchanged before/after:17618s summed execution,21
carried-forward unknown delays, identical complete summary digest.
- Three alternating reporter RSS pairs on the same archived input, actual time-l peak
KiB: main 22224 / 22576 / 22528; candidate 22448 / 22528 / 22416. No stable memory
improvement is claimed.
- Corpus --both: 963/963 hash ON/OFF; VM 963 VM /0 fallback /0 differences. Ordinary O2
build, runtime inputs unchanged from main94424798.
- Eight source gates, bracket check and default hygiene pass; explicit changed-record
hygiene checked separately.

Clean Ruby4.0.10 via `tools/ref_ruby.sh`, revision
a704b7cd95a42cc0cf5f307137bf3aac0285b915, no extras, Prism1.8.2. No Rails or native-gem
acceptance is claimed for this reporting-only change. Proof, source/binary digests and
UTC cohort times: `loop/2026-11-26-codex-rails1-ci-cancellation-timing.json`.
