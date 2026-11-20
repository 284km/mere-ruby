# Native RSS ownership investigation

`rss-native-retention.yml` builds the exact previously failing runtime
`dde0f90c` on native Ubuntu x86-64, once for each existing CI compiler pin.
The pins, source commit and upstream Ruby commit are fixed in the workflow.
This is a separate job; existing jobs, bounds and assertions do not change.

Both builds finish before measurement. The ordinary interpreter first runs
the unchanged complete upstream Module control and paired Method-copy check.
Their failures remain failures even if the later diagnostics complete. The
ordinary selected clone case also retains its original assertions, child
stdin and ten-second child timeout. Each file/side retains 600 seconds and
2 GiB. The Method-copy check still tests every post-GC prefix against 2x.

The second interpreter is a private copy of the same emitted C, compiled
with the same O2 flags. Its build script only stamps a different mode,
`DIAGNOSTIC O2 RSS observer`. The ordinary gate must reject this binary.
The emitted-C copy adds explicitly enabled, read-only observations before
the subject's existing
`/proc/self/status` opens and `/bin/ps` spawns, and at exit. No Ruby subject
byte, argument, reference implementation or timeout is replaced. In the
selected-case diagnostic, a native environment PID exclusion set before exec
suppresses the test parent so its verbose case identifiers remain intact.
Only its child emits ownership data.

Each observation records real resident memory, current native map rows,
physical slots, pin floors and arena capacities, the default arena, the
cache, retired arena generations,
and their saved pinner handles and current coroutine states. It never invokes
collection, compaction, the pin hook, retirement, deallocation or a GC API.
Native layouts are private to the locked compiler; a changed observation
site must fail the build rather than silently omit data.

These are calling-thread observations, not a census of every native thread.
Capacity is not RSS. A saved pinner can have moved since retirement; cached
pin words are invalid after resumption unless the recorded validity flag
says otherwise. A current/root pinner is not proof that its pointers are
stale or safe to release. Logging can change native allocation and layout,
so its ratios never replace those of the ordinary binary.

The artifact retains the ordinary results, original child input, raw logs,
hashes, separate diagnostic build provenance and per-sample ownership.
Missing or truncated samples fail collection. A completed diagnostic is not
a memory repair and does not waive any earlier failed hosted observation.

To build and collect outside CI using separate locked checkouts:

```sh
LANG=en_US.UTF-8 python3 tools/rss_native_probe.py build \
  --subject /path/to/ordinary-subject --diagnostic-root /path/to/probe
LANG=en_US.UTF-8 python3 tools/rss_native_probe.py collect \
  --subject /path/to/ordinary-subject --diagnostic-root /path/to/probe \
  --reference /path/to/ruby --ruby-src /path/to/ruby-source \
  --output /path/to/results
```
