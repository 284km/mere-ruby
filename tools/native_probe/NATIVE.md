# Native extension boundary: the investigation probes

These sections were written with the prototype, one per stage. They describe
what each check script under this directory builds and compares.

## Native exception investigation

The `feat/native-ensure` prototype connects unchanged Ruby 4.0.9
`ext/-test-/exception/ensured.c` through a small investigation header.
Build with a Mere compiler containing `merelang/mere` PR #40, then run:

```sh
MERE=/path/to/mere sh tools/build.sh --fast
python3 tools/native_probe/ensure_check.py \
  --ruby-source /path/to/ruby-4.0.9 \
  --reference /path/to/ruby-4.0.9/bin/ruby \
  --output /tmp/native-ensure-results
```

The validator builds the same C input against each runtime's headers and runs
both original exception tests, shared behavior checks, GC stress, and negative
controls with C cleanup disabled. Each interpreter run has a 90-second and
2-GiB process-family limit. It requires permission to inspect processes.

Callbacks capture Ruby exceptions and nonlocal flow in rooted outcome tokens,
return to C, and resume unwinding only after C has released its resources.
The C `setjmp` guards never jump across a Mere callback frame. Cleanup errors
override body errors; the boundary preserves exception identity, `$!`, cause,
backtrace, and the original raise event. Temporary roots belong to one native
invocation, including nested invocations, and are released on both exits.

This is a synchronous interpreter-thread experiment on macOS / O1. Its tokens
are not CRuby's VALUE ABI. The original adapter supports one- and two-argument methods;
`rb_funcall` transports up to two arguments (the original input exercises zero).
The original Ruby adapter routes calls to registered C methods; the native
loader experiment below replaces that routing for its supported API.
Asynchronous callbacks, thread/fiber suspension, and
system allocation failure recovery remain outside this experiment. The older
float adapter uses a separate value representation. These results do not
change the main branch's test scoreboard.

## TypedData investigation

The `feat/native-typeddata` prototype adds owner-based mark/free support to the
native exception experiment. Rebuild with the same compiler, then run:

```sh
python3 tools/native_probe/typeddata_check.py \
  --ruby-source /path/to/ruby-4.0.9 \
  --reference /path/to/ruby-4.0.9/bin/ruby \
  --output /tmp/native-typeddata-results
```

The validator compiles the original `typeddata.c` and `dataerror.c` unchanged
for both runtimes, runs their complete test files (4 tests / 20 assertions),
and compares a shared C box fixture. There are 78 shared behavior checks and
4 native bookkeeping checks. Normal execution and GC stress pass; disabling
mark or free fails the corresponding negative control. Original input hashes
are checked before and after the runs. Limits remain 90 seconds and 2 GiB per
process family, including the original million-allocation child process.

Borrowed tokens are rooted while their C invocation is active. Outside that
invocation, only dmark on a reachable owner keeps a stored token and its Ruby
value alive. The collector follows C edges in its ordinary object fixpoint,
so C/Ruby chains and cycles have the same reachability rules. Dead owners are
detached before dfree, and descriptor fields are cached first: the original
dynamic-type test frees its descriptor inside dfree. Expired returned tokens
raise after releasing temporary roots. Weak token tables and owned C payload
bytes contribute to memory pressure accounting.

The existing conservative stack scan can delay some unreachable owners. The
shared fixture checks actual reclamation and tracks allocation generations to
detect double free; it does not require every unreachable object to disappear
after a fixed number of collections. Disabling the stack scan is used only as
a separate diagnostic, never for the normal success result.

This remains a local macOS / O1 experiment. Its original validator uses
fixture-specific Ruby routing; the loader below also tests ordinary require.
Embedded storage is emulated by a separate allocation;
free callbacks run synchronously during sweep, without reproducing CRuby's
deferred-free scheduling. Movable marking/dcompact, generational barriers,
shutdown finalization, the full extension API, and the CRuby binary
ABI remain unimplemented. Mark/free callbacks must not invoke Ruby or allocate.
C-side ASan/UBSan validation covers the bridge and the unchanged extensions;
the generated interpreter is uninstrumented. That run uses
`ASAN_OPTIONS=use_sigaltstack=0` for the runtime's coroutine stack management.
It is not a whole-interpreter sanitizer or leak-freedom claim.

## Native registration and require investigation

The `feat/native-loader` prototype connects C module/class definitions,
fixed-arity methods (0..2 arguments), module functions and allocators to the
ordinary Ruby method tables. Inheritance, aliases, visibility, argument checks,
blocks and `super` use the interpreter's existing dispatch. Allocators receive
the actual subclass, and `new` invokes its Ruby `initialize` normally.

```sh
python3 tools/native_probe/loader_check.py \
  --ruby-source /path/to/ruby-4.0.9 \
  --reference /path/to/ruby-4.0.9/bin/ruby \
  --output /tmp/native-loader-results
```

This validator uses native bundles directly through `require`, with no
extension-specific Ruby routing files in its load path. It checks 41 shared
contracts plus 4 native bookkeeping contracts, including GC stress, repeated
require, absolute/symlink identity, `.so` aliases, `require_relative`, nested
and circular loading, Ruby-file precedence, and initialization failure/retry.
The unchanged upstream TypedData and exception test files, plus the selected
`test_marshal` roundtrip, pass 7 tests / 31 assertions on both runtimes.
The remaining Marshal compatibility cases are not included. Original input
hashes and exact result counts are checked; each process family retains the
90-second / 2-GiB limit.

The loader resolves `Init_<basename>` and requires this prototype's ABI marker.
Extensions must be rebuilt against its headers with `PROBE_TYPED_API`; CRuby
binary extensions cannot be loaded. A failed Init removes the loaded-feature
entry but leaves its partial Ruby definitions, matching CRuby. Libraries stay
resident after opening successfully so those methods and TypedData callbacks
remain callable; retry invokes Init again on the same library state. ABI or
missing-Init failures close the handle before invoking Init.

This is still a local macOS / O1, synchronous prototype, with limits of 512
class-name slots, 4096 method slots and 128 resident libraries. It does not
implement variable-arity C entry points, concurrent loading, unloading,
automatic discovery of all C roots, or the rest of the Ruby C API. Existing
TypedData and exception limitations above still apply. The mkmf experiment
below connects source builds. The older float probe remains available for
regression checks with its separate adapter and value representation.

`--mere /path/to/instrumented-runtime --sanitize-extension` validates C-side
ASan/UBSan builds; `--select` can restrict run names. Instrumenting only the
bridges and extensions does not instrument the generated interpreter.

## Native builds with mkmf

The `feat/native-mkmf` prototype runs the unchanged Ruby 4.0.9 `mkmf.rb` on
mere-ruby, then uses its Makefile to compile and link native extensions.
`tools/native_probe/build_config.rb` explicitly supplies RbConfig with this
worktree's headers, compiler and linker settings. Load it with `-r` before
`-rmkmf`; it does not change the default runtime configuration. The prototype
uses macOS bundles and resolves interpreter symbols at load time, without
linking against libruby.

```sh
python3 tools/native_probe/mkmf_check.py \
  --ruby-source /path/to/ruby-4.0.9 \
  --reference /path/to/ruby-4.0.9/bin/ruby \
  --output /tmp/native-mkmf-results
```

The output directory must be empty. The validator runs both runtimes, captures
compiler commands and checks original source hashes. It stages unchanged
float `extconf.rb`, `auto_ext.rb`, `init.c`, `nextafter.c` and
`missing/nextafter.c`, preserving their include layout. CRuby's generated
internal-header dependency list is omitted; mkmf generates dependencies for
this header set. The upstream in-tree extconf needs `top_srcdir`, supplied as
a make variable pointing at the staged source. No source patch or Ruby routing
adapter is used for these float calls.

`NUM2DBL` / `DBL2NUM` now use the common scoped VALUE path. The unchanged
nextafter file passes 400 tests / 1,225 assertions. Another 13 checks cover
numeric coercion, nested calls, GC, exceptions, NaN and signed zero, in normal
and GC-stress execution. The existing loader checks pass with mkmf-built
fixtures, including TypedData allocation and Init failure/retry. The unchanged
`test/mkmf/test_mkmf.rb` passes 94 tests / 188 assertions on both runtimes.

The build checks actually compile/link positive and negative header/symbol
probes. An intentionally failing compiler must stop extconf without producing
a Makefile. A related interpreter fix permits implicit calls with a forwarded
block to included private methods on main, retaining singleton precedence.

This is an opt-in macOS / O1 experiment, not installed headers or full gem
build support. The small header set exposes only the implemented probe API.
It does not provide CRuby's internal types or binary ABI. Passing the global
mkmf file does not establish success of all 17 mkmf files: the in-tree test
base also needs build-tree metadata and configuration in child interpreters.
Default RbConfig, installation/packaging, Linux/O2, and full-suite validation
remain separate work. Prior native lifetime and threading limits still apply.

For C-side sanitizer validation, pass `--side mere --sanitize-extension`
and `--mere /path/to/instrumented-runtime`. The validator adds ASan/UBSan
through mkmf's compiler/linker options and uses `use_sigaltstack=0`; the
generated interpreter can remain uninstrumented, as in the earlier probes.

### Target-specific probe headers

The optional header generator measures `sizeof` using compilation only. It
does not link or execute target programs, and reads `VALUE` from the probe API
rather than copying CRuby's layout. It generates a separate header tree with
`SIZEOF_*`, `LONG_LONG`, and `<limits.h>` for `CHAR_BIT`:

```sh
python3 tools/native_probe/configure_headers.py \
  --cc clang --cflags='-O2 -arch arm64' \
  --output /tmp/mere-native-arm64
MERE_NATIVE_CONFIG_DIR=/tmp/mere-native-arm64 \
  ./mere-ruby -r ./tools/native_probe/build_config.rb -rmkmf extconf.rb
```

Use a fresh output directory per target. Compiler commands, flags, header
hashes, sizes, and compilation diagnostics are recorded alongside the headers.
Generation publishes the directory only after verification; existing output,
an unusable compiler, or a compiler accepting invalid code causes failure.
Generated headers also check their sizes against the extension's actual C types.
Supply target/sysroot options in the compiler flags. The opt-in RbConfig uses
the recorded commands and flags; conflicting environment overrides fail and
require regeneration. `MERE_NATIVE_CONFIG_DIR` must be passed to child Ruby
processes as well. The suite helper below normalizes it and stages the same
headers for in-tree tests, while the reference keeps its own headers.

Run the generator checks with a real target toolchain:

```sh
python3 tools/native_probe/configure_headers_check.py \
  --cc clang --cflags='-O2 -arch arm64' --output /tmp/native-header-check
```

Header generation and C compilation are validated on macOS arm64/x86_64 and
Linux x86_64 GCC 15. Linux extension loading and the mkmf build configuration
remain unvalidated; the existing macOS guard stays in place. These generated
headers do not supply embedding functions or a runtime archive.

### Measuring all mkmf files

The test environment prototype stages unchanged `test/mkmf` and `lib/mkmf.rb`
inputs, generates a real Makefile, and supplies the in-tree header layout.
An explicit launcher preloads the build configuration in parent and child
interpreters, including children started through PATH or with `-w`, `-I` and
`-C`. The default runtime configuration remains unchanged.

```sh
python3 tools/native_probe/mkmf_suite_check.py \
  --ruby-source /path/to/ruby-4.0.9 \
  --reference /path/to/ruby-4.0.9/bin/ruby \
  --reference-build /path/to/matching-ruby-build \
  --output /tmp/mkmf-suite-results
```

Use an empty output directory. The reference needs its matching static Ruby
library because in-tree mkmf probes select `LIBRUBYARG_STATIC`, even for a
shared Ruby installation. Libraries absent from the installation are taken
from `--reference-build` (default: the source directory). Mere uses only its
own probe headers and does not link libruby. No C API stubs or test assertion
changes are introduced by the launcher.

Before measuring, the helper checks parent/child configuration, rejects a
raw interpreter missing the preload, and compiles positive and negative
header/symbol probes. Every measured command has a 90-second / 2-GiB process-family
limit. It saves input and binary hashes, Makefiles, compiler preflight logs,
test transcripts, per-case results and comparisons. Test inventories must
match; incomplete transcripts or changed inputs fail the measurement.
**Exit zero means measurement completed, not that every test passed.**

On the macOS / O1 prototype, all 17 files complete. CRuby reports 148 tests,
419 assertions, no failures/errors and 4 skips. Mere reports 148 tests,
401 assertions, 7 failures, 6 errors and 4 skips. Eight files pass fully
(`configuration`, `convertible`, `flags`, `have_macro`, `install`, `libs`,
`mkmf`, `signedness`); eight have
failures/errors, and `pkg_config` skips all four cases on both runtimes.
The remaining obstacles are:

- An unassigned local after short-circuit evaluation (`framework`).
- Target RbConfig selection (`config`) and PATH-dependent `Process.uid` in
  `File::Stat#executable?` (`find_executable`).
- Missing probe-header size/limits definitions (`constant`, `sizeof`), unsupported
  embedding API `ruby_init` (`egrep_cpp`, `have_func`), and a test archive-name
  assumption derived from the absent `LIBRUBY_A` (`have_library`).

The framework reports 131 successful cases, but this is not proof that every
reference assertion was reached: `constant#test_long` returns early with the
current missing size macros. Skips and that limitation remain visible in
the results. These measurements do not update the main-branch scoreboard or
establish Linux, O2, installation or general extension compatibility.

`String#%` reached through `super` now uses the ordinary formatting operator's
builtin implementation, preserving coercion and result encoding. Singleton
overrides with a literal block also reach the builtin fallback, as calls
without a block already do. The regression covers singleton/subclass/prepend
lookup, explicit and forwarded arguments, coercion, encoding, arity errors,
ignored blocks and builtin iterator blocks, including GC stress. The unchanged
`test/ruby/test_sprintf.rb` passes 33 tests / 37,672 assertions on both runtimes.
This resolves all six formatting lookup errors in the three mkmf files:
`convertible` and `signedness` pass fully, while `sizeof` now reaches a separate
failure caused by the missing `SIZEOF_INT` header definition. Its builtin-size
case also skips conditional assertions while size macros remain absent.

