# Action Pack runtime protocols and suite accounting

The earlier integrated runtime was based on main 976bb95d. Rails is the unchanged
8.1.4.1 tag, commit 3f290b759c8e2ffe7c257951b1255740751355e4.
No upstream tests or component libraries are patched. That focused
replay has 1091 MATCH and two C API-owned RED across 26 files, including two
known files without runnable tests. The post-#235 full run is recorded in
`2026-11-25-codex-actionpack-full-20261125.md`: 4,152 MATCH and zero RED across
all 173 files. Timing and RSS below predate #235 and are historical.

## Framework tooling

The conservative lock adds Action Pack's integration/system dependencies,
keeping existing locked versions. There are 85 archives. A framework-only
bootstrap restores bundled_gems, did_you_mean and error_highlight, which
--disable-gems suppresses. Application/install startup is unchanged.

The optional --require-all-pass requires complete matching test inventories
with zero failures, errors or skips. EMPTY is limited to two named tagged
sources with matching sizes and SHA-256 digests: the zero-byte Journey symbol
file and controller/new_base/render_xml_test.rb. An unavailable memcached
backend reporting zero runs cannot be accepted as EMPTY. The parser retains
pending test identities across memcached diagnostic lines and rejects
unfinished, duplicate or inconsistent results. Harness controls: 26 passed.
A real unavailable-backend replay reports ZERO on both sides and correctly
exits 1, with zero EMPTY and one unusable reference. The positive replay with
memcached reports 13 actual MATCH. Defaults and the 600-second / 2-GiB
per-file-family bounds are unchanged.

## Runtime changes

- Primitive subclass respond_to? super reaches the native visibility protocol.
- Undefined class variables can be initialized with ||= in either AST shape;
  short circuits preserve frozen-class behavior.
- require and require_relative overrides receive their original arguments.
- Hash#delete super preserves its block, missing values and frozen checks.
- Backtrace node lookup uses the public Prism API even with native Prism.
  Walking prunes subtrees outside the location's line. The cache is
  bounded to 128 node-id answers and retains no complete Prism trees.
- Kernel#method super, private reflection and exception initializer visibility
  preserve the native methods' contracts. Class receiver overrides also win.
- Hash#values_at honors overrides, default behavior, aliases and bound methods.
- A bare alias of a native method retains the passed block.
- Container equality uses String's equality protocol for string-like objects.
- Array#join invokes native object conversion, including backtrace locations.
- Eval compile errors retain the appropriate backtrace metadata; unfinished
  assignments include both missing-expression and end-of-input diagnostics.
- Logical line markers distinguish multiline literals separated by semicolons,
  including a semicolon and EOF on the same physical line.
- Nested cause exceptions retain their own saved backtrace and locations.
- Rescue splats accept method chains as complete runtime expressions.
- `yield ::C` passes a top-level constant, while `yield::C` resolves C from
  the yielded receiver, allowing RubyZip to load unchanged.

Hash patterns also retain the returned Hash and use its key?, [], dup, delete
and empty? callbacks in Ruby's order. Primitive copy dispatch respects singleton
and private overrides while using the native super-copy path merged on main.

Corpus 1000-1017 contains focused regressions. Before the first four-digit
file, selection was checked: run_corpus.sh uses corpus/*.rb and
 tools/iseq/vm_corpus.sh uses the same unrestricted glob. record_hygiene
checks tracked records rather than selecting corpus programs; its explicit
file mode also accepts the new loop record. No selector change was needed.

## Integrated regression gates

Ordinary O2 build, compiler revision 9dec2ff687a08433247dbdb7729bc19c8522e538.
Runtime revision e80252c60da8a267586f2b1b66fee3d04821109a, binary SHA-256
5c2d4b77ed8d7efaef0354403fccdcfc1f9cf2ee682abee06bfd57b110f7a7d1.
The later strict-empty-file correction changes only framework tooling/docs;
its gate revalidates the earlier focused results without rebuilding runtime.

- Complete run_corpus.sh --both: 887/887 match, hash index ON and OFF;
  830.929 seconds, maximum family RSS 1182432 KiB, no resource event.
  Original bounds remain 900 seconds / 2 GiB. The fixture hash manifest is
  recorded and unchanged throughout the run.
- Complete MERE_RUBY_VM=1 corpus: 883 VM, 4 fallback, zero differences.
  The inventory is exactly the same 887 files, including four-digit names.
- All 18 new regressions and four related main regressions match reference
  under evaluator and VM with GC stress period 50: 44/44 runs.
- Ruby's core tests pass on reference/evaluator/VM: Array join 8 tests and
  88 assertions; Hash default/delete/values_at 10/50; cause 3/10; hash patterns
  and error matchees 3/80.
- Source gates pass: duplicate/dead definitions, name lengths/specification,
  namespace names, method writes, regex capture writes and GC roots.
  Generated C bracket depth is 155 against the build's 1024.
- Existing C API contracts pass on both sides and under GC stress; all six
  negative controls fail as required. There is no capi/ diff in this branch.
- Record hygiene passes on the source records and the new explicit records.

## Action Pack comparisons and memory

Same tagged source, seed 12345, MT_CPU=0, reference binary, framework bootstrap,
archive lock, gem installation provenance and original resource bounds.
Separate private gem homes/TMPDIRs prevent overlapping focused batches from
sharing mutable files. These are diagnostic replays: --other-install-binary
records that native gems were installed by an earlier binary. A fresh final
native gem installation is still required before the complete-suite claim.
Both independently installed sets of twelve component lib trees match the tag.

The latest-main baseline is 976bb95d. Four files (controller/helper,
dispatch/test_response, dispatch/routing_assertions and dispatch/routing)
move from 401 MATCH / 20 RED to 421 MATCH / zero RED. Main already passes the
routing assertions themselves; its failures are helper's 18 and JSON patterns' 2.
The routing files are retained for memory comparison, not credited as new fixes.

Additional four-file controls were measured against the earlier main 30de57d4:
browser/accessors/log_unpermitted/nested_permit move from 108 MATCH / 12 RED
to 120 MATCH / zero RED. Permit/raise_unpermitted/required/TestResponse move
from 72 MATCH / 12 RED to 84 MATCH / zero RED. Each baseline record explicitly
distinguishes the runner revision from the actual runtime revision.

Maximum process-family RSS in KiB:

| File | main 976bb95d | Integrated | Change |
| --- | ---: | ---: | ---: |
| dispatch/routing_assertions_test.rb | 676080 | 600576 | -11.17% |
| dispatch/routing_test.rb | 646720 | 519552 | -19.66% |

Elapsed times are recorded too; this shared-machine comparison is not an
isolated timing benchmark. DebugExceptions passes all 49 tests / 402 assertions
in 278.4 seconds, peak 1103888 KiB. The backtrace helper caches at most 128
node IDs, retaining no complete Prism trees.

All focused native batches together cover 26 unique files: 1091 MATCH,
two RED, two EMPTY; zero unusable references, missing/unconfirmed/extra tests,
order differences or skips. System-testing files contribute 46 MATCH; the
running memcached backend contributes 13 actual MATCH. The stricter current
gate revalidates every positive batch. The HTTP/Inspector batch correctly
fails that gate for its two known errors. VM focus (helper, expect, mutators,
TestResponse) has 92 MATCH and zero RED.

Portable records are under railstest/framework/records/actionpack-integrated-*.
The summary identifies all six native batch records; it is explicitly marked
full_suite=false. Raw logs and local paths are not committed.

## Independent reference

Every result here uses a separate Ruby 4.0.10 build from source revision
a704b7cd95a42cc0cf5f307137bf3aac0285b915; binary SHA-256
5ad9092ceb67b18b9ed512ad3fbcf309910c7ad7d2fabb3d85d5228a51eb8df0.
The editor-managed rbenv reference was never used. Audits after the pollution
notice and after integrated verification found the same 84 default/bundled
specifications, all within that reference prefix, and zero extras. The complete
gem list and manifest audit are recorded. Default Prism is 1.8.2; the locked
framework gem homes' intentional native Prism 2.1.0 is independently controlled.
Framework gems never write to the reference's Gem.default_dir.

## Full measurement and CI follow-up

The independently submitted IO.console and SQLite fixes were merged as
#238 and #237. Both are included in the frozen full-run build `8624fb60`,
together with main #235 and this branch's runtime changes. Fresh native-gem
installs and all 173 files passed the optional strict gate: 4,152 MATCH,
zero RED / MISSING / BOTH / UNCONFIRMED / EXTRA, and two verified EMPTY files.
The full record is `railstest/framework/records/actionpack-full-8624fb60.json`.

The owner authorized the heavy slot; the run completed on 2026-11-24 at
23:51:41 UTC and the slot was released for work2026-df's full unit-test run.
No file hit WALL_LIMIT or MEMORY_LIMIT. The completed Linux CI replay at
882177ca also passes the unchanged Module gate: 195 tests, 1,240 assertions,
zero failures/errors/skips. Earlier attempts had two child timeouts; their
cause is not established. The exact CI merge and binary digests are in
unittest/records/actionpack-module-linux-882177ca.json.


## Pinned main integration after the full measurement

Merge f67fbe160403d2c769f7ccef84178e484f7e8f8e incorporates main
323706a7. The Array#join conflict preserves the main stream's separate
Class#to_s dispatch and this branch's conversion fallback for other objects.
This is a new build, not the frozen 8624fb60 full-suite cohort above.
The three focused Rails files remain 90 MATCH / zero other classifications,
all COMPLETE on both sides. Their runner is from 8624fb60; the measured
binary is f67fbe16, digest 06b6c5797a38a9e7e103567f68c3b11f54e95bd5cfc1eabeef7e722e5eaf74eb.
Native gems are explicitly reused from the exact 8624fb60 install.
CRuby Array join runs 8 tests / 88 assertions with no failures/errors/skips
on reference, evaluator and VM. Corpus 976 and 1009 match on both modes.
The portable evidence is railstest/framework/records/actionpack-main323-focused.json.
The complete corpus checks for this merged build are running separately;
the completed 897-program counts above apply to the frozen full-run build.
