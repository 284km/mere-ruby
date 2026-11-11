# NKF and Kconv

`require 'nkf'` provides `NKF.nkf(options, source)`, `NKF.guess(source)`,
the corresponding private module functions, and the reference constants.
`require 'kconv'` loads the original Kconv Ruby implementation and its String
extensions. Conversion uses the same C engine in native builds and the browser;
it never delegates conversion to an installed Ruby or an external command.

The source is ruby/nkf **0.2.0**, commit
[`65506fecfd6bec82552746473bb91899d861a849`](https://github.com/ruby/nkf/tree/65506fecfd6bec82552746473bb91899d861a849),
with NKF **2.1.5 (2018-12-15)**. Original licenses, hashes, tests, and ordered
local patches are in `vendor/nkf/UPSTREAM.json`. Kconv and conversion tables
are unchanged. Five local core patches guard kana, MIME EOF, Shift_JIS and
JIS X0212/X0213 table boundaries and forward ISO-2022-JP EOF before a signed
shift. The source checker reverses the complete patch chain to verify the
original hash, then reapplies it and checks the exact shipped source.

The original all-byte input reads outside the reference's kana tables.
Its 71 affected option combinations have explicit safe output expectations in
`unittest/nkf_malformed_policy.json`; they are recorded separately from the
1,411 exact reference conversion comparisons. Generated malformed bytes are
sanitizer checks, without a reference compatibility claim.

Native engine phases serialize access to the upstream global state. Ruby
`to_str` callbacks run between phases, preserving nested and interleaved
conversion behavior. The experimental embedding API retains its existing
single VM / serialized host-thread contract. Cleanup runs after exit hooks and
scheduler teardown, including protected cleanup failures. Output buffers are
copied before another Ruby callback and released immediately.

Each browser run gets a fresh NKF reactor. The JavaScript bridge copies
length-prefixed bytes between the two memories. An allocation failure raises a
Ruby exception after replacing the interrupted reactor; unexpected traps remain
host errors. Browser threads retain the playground's existing capability limit.

Native builds use `sh tools/build.sh`. To rebuild both browser modules, set
`WASI_SDK_PATH` to **WASI SDK 34.0** and run `sh docs/build.sh`. The release
archive SHA-256 is
`9c59398106b417f8f14913380fdf0097a8cc0ff4af9eb3ce0065a859e88d49e9`
for arm64 macOS and
`b761e3a0721dbae9c09a0059e5fdb2bf917d1b4a8a7b430fb3b5aafb0984b2c4`
for x86-64 Linux. The build does not download a toolchain implicitly.

Reproducible checks (the reference Ruby must have nkf 0.2.0 installed):

```sh
python3 unittest/nkf_sources_check.py
python3 unittest/nkf_api_check.py --ruby /path/to/ruby --wasm --output /tmp/nkf-api
python3 unittest/nkf_boundary_check.py --ruby /path/to/ruby --output /tmp/nkf-boundaries
python3 unittest/nkf_upstream_check.py --ruby /path/to/ruby --ruby-source /path/to/ruby-source --output /tmp/nkf-upstream
python3 unittest/nkf_tool_check.py --ruby /path/to/ruby --source /path/to/ruby-source --output /tmp/nkf-tool
NKF_WASM_TEST=1 NKF_WASM_OUTPUT=/tmp/nkf-fault.wasm sh tools/build_nkf_wasm.sh
node unittest/nkf_wasm_boundary.mjs /tmp/nkf-fault.wasm
```

The original upstream suite has 7 tests / 44 assertions. Additional corpus
programs exercise coercion/error ordering, reentry, constants, Encoding aliases,
loading retries, method visibility and metadata, copies, hooks and Ruby threads.
These checks complement the existing complete corpus and embedding gates.
