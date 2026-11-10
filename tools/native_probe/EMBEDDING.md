# Protected embedding prototype

The generated `mere_embedding_*` interface runs one interpreter instance on
one host thread. Serialize calls. It is experimental and does not implement
the CRuby `VALUE` ABI, `ruby_init`, or `ruby_cleanup`.

Build with the published Mere revision pinned in CI and an O2 Prism archive:

```sh
python3 tools/native_probe/embedding_check.py \
  --compiler .mere-compiler/_build/default/bin/mere.exe --output build/embedding
python3 tools/native_probe/embedding_stress_check.py \
  --library-dir build/embedding --prism-lib vendor/prism/obj/libprism.a \
  --output build/embedding-stress
python3 tools/native_probe/embedding_bundle.py \
  --library-dir build/embedding --prism-lib vendor/prism/obj/libprism.a \
  --output build/embedding-bundle
```

OpenSSL 3 development headers and libraries are required, as for the native CLI.
Provider flags come from `OPENSSL_PREFIX`, Homebrew on macOS, or `pkg-config`.
The archive includes OpenSSL glue; consumers also link the provider libraries
using the system flags recorded in the manifest.

Use fresh output directories. On Linux, set `ulimit -s 524288` before running
the generated interpreter. The bundle contains the generated header and a
static archive including Prism and native glue; consumers need only that
archive and the system link flags in `manifest.json`. `build-config.json`
keeps unexpanded templates separate from expanded paths. A target's generated
headers, object files, and Prism archive must all describe the same target.

Call `mere_lib_init`, then `mere_embedding_setup`. The generated C header
describes the outer Mere status and output parameters. The inner setup/eval
result is 0 for success, 1 for a protected Ruby exception, or 2 when the
lifecycle refuses the operation. Evaluation retains the top-level binding,
methods, constants, and captured blocks across calls.

A protected exception remains pending. `error_class`, `error_diagnostics`,
and `exception_status` inspect it without consuming it; further evaluation
is refused. Call `clear_error` to acknowledge it and resume evaluation, or
call `cleanup` to finish with that pending error. `SystemExit(0)` is still a
protected exception even though its exit status is zero.
Diagnostics read the stored exception class and message without invoking
Ruby methods such as an overridden `inspect`. Primitive errors are retained
as Ruby's pending `$!`, just like explicitly raised exceptions.

Cleanup runs exit hooks in Ruby's order, flushes open output, and terminates
the scheduler, then releases the native OpenSSL handles owned by this
instance. Hooks and thread ensure clauses can still use those objects before
teardown; unrelated native handles owned by the host remain intact. Native
ownership is drained even after a protected cleanup failure. A later hook
failure or SystemExit replaces the pending exit status. Diagnostics remain available independently of the final status.
Repeated cleanup returns the same status and does not rerun hooks. A failed
setup may also be cleaned up. Afterwards, release generated return buffers
with `mere_lib_free` and call `mere_lib_shutdown` to release instance storage.

The API does not install Ruby signal handlers. Ruby `exit!` and `exec` remain
process control operations and are not protected failures. Host callbacks
must not reenter this singleton interpreter or call it from another thread.

The tests compare lifecycle behavior with Ruby and exercise cleanup
precedence, retained state, output flushing, and fixed scalar/string workloads
at 1,000, 10,000, and 100,000 evaluations. Those allocation checks do not
establish bounded memory for every Ruby program or full Ruby compatibility.
Native ownership tests repeat initialization, cleanup and shutdown in one C
process, checking live native counts after GC, hooks, thread teardown, pending
exceptions and SystemExit. CI also builds separate `--setup-failure` and
`--cleanup-failure` fixtures for partial initialization and failed scheduler
teardown. Injected failure fixtures cannot be packaged as consumer libraries.
C compilation has a 3-GiB memory budget; interpreter runs retain the 2-GiB limit.
