# Action Pack: runtime contracts and complete suite accounting

Work in progress, originally measured against main 30de57d4 and rebased onto
976bb95d after the other runtime fixes merged. Rails is the unchanged
8.1.4.1 tag; the reference is Ruby 4.0.10 from tools/ref_ruby.sh.
The final complete run waits for the owner's schedule, to avoid overlapping
Rails-2's full measurement. All checked-in results must distinguish evaluator
and VM execution. No upstream Rails tests or component libraries are patched.

## Framework tooling

The conservative framework lock adds Action Pack's integration/system test
requirements, preserving existing locked packages. There are 85 archives.
A framework-only bootstrap restores bundled_gems, did_you_mean and
error_highlight, suppressed by --disable-gems. Installation/application
startup remains unchanged.

The optional --require-all-pass gate requires both complete inventories,
matching test identities and zero failures, errors or skips. It accounts for
two upstream files without runnable tests as EMPTY, with zero MATCH.
Verbose results interrupted by memcached log lines are parsed with their
original pending test identity; unfinished or duplicate results still fail.
Harness controls: 25 passed.

## Runtime changes being validated

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

Corpus 1000-1017 contains focused regressions. Before the first four-digit
file, selection was checked: run_corpus.sh uses corpus/*.rb and
 tools/iseq/vm_corpus.sh uses the same unrestricted glob. record_hygiene
checks tracked records rather than selecting corpus programs; its explicit
file mode also accepts the new loop record. No selector change was needed.

## Measurements and remaining verification

The initial evaluator run at b7fe86e1 selected all 173 files: 3963 MATCH,
74 RED, 56 BOTH, 7 reference-unusable files. It preceded the framework-only
startup correction, which subsequently made the affected reference tests pass.
The exact final inventory will be recorded after independent native gem
installation and the owner's authorization for the full run.

Intermediate diagnostic builds included a candidate C API hidden-constant fix.
Their results do not establish that this branch alone passes those tests.
That patch and its shared C/Ruby fixture were separated for the C API owner;
no capi/ change is included here. IO.console's internal `console` constant
requires native constant-defined/get/remove behavior without Ruby's public
constant-name validation.

Required final checks remain: complete evaluator corpus with both hash modes,
VM corpus with VM/fallback/difference counts, source gates, record hygiene,
focused Action Pack before/after counts and maximum family RSS, and finally
the scheduled complete Action Pack run. No all-pass claim yet.

## Independent reference audit

Every measurement in this stream uses a separately built Ruby 4.0.10, not
the editor-managed rbenv installation. Source revision:
a704b7cd95a42cc0cf5f307137bf3aac0285b915. Binary SHA-256:
5ad9092ceb67b18b9ed512ad3fbcf309910c7ad7d2fabb3d85d5228a51eb8df0.
An audit after the pollution notice found 84 gem specifications, all under
that private reference prefix, and zero versions outside its default gems
and the exact bundled_gems manifest. Prism is default 1.8.2. Framework gems
are installed in separate controlled homes; their locked Prism 2.1.0 is
intentional and unrelated to the editor's extra Prism 1.9.0.

## Intermediate checks

- First ordinary O2 build: 881/881 corpus programs match the clean reference
  with the hash index ON and OFF, 872.683 seconds, maximum family RSS
  1080064 KiB, no resource event. This precedes corpus 1015 and the bounded
  node-id cache; final corpus and VM counts remain pending.
- System-testing files: 46 MATCH, zero RED/missing, without C API changes.
- VM focus: helper, parameters_expect, mutators, mime_type and system driver:
  138 MATCH, zero RED/missing.
- Ruby core tests on reference/evaluator/VM: Array join 8 tests/88 assertions;
  Hash default/delete/values_at 10/50; exception cause 3/10. All pass.
- Fifteen initial regressions pass in both modes under GC stress period 50,
  30 runs with zero differences. The final sixteen are being rechecked.
- A four-file comparison using the same corrected startup moved 432 MATCH /
  27 RED to 459 MATCH / 0 RED. It used the earlier b7fe86e1 binary as the
  baseline; a new baseline at 30de57d4 is being collected for memory analysis.

The full-suite slot is explicitly after the Rails cold measurement and
Rails-2's multi-hour activerecord round 3. Do not start it without the owner.

## Hash pattern protocol and remaining owner dependency

TestResponse's two JSON pattern failures were raw-pair lookups bypassing
HashWithIndifferentAccess#key? and #[]. Hash patterns now keep the returned
Hash, check all keys before matching values, and use #dup/#delete for a named
rest or **nil. Native primitive #dup/#clone also respect subclass overrides
and resume the native copying operation through super. Corpus 1016/1017
cover the protocol, ordering, actual error matchee, visibility, rest class,
copy overrides and copied instance variables on Hash, Array and String.

All eighteen new regressions match the independent reference under evaluator
and VM with GC stress period 50: 36 runs, zero differences. Ruby's own hash
pattern/deconstruct_keys tests pass on all three: 3 tests, 80 assertions.
TestResponse now has 5 MATCH, zero RED (its two pattern failures are gone).

Routing Inspector still has two errors without the other stream's C API
change: test_not_routes_when_expanded and
test_no_routes_matched_filter_when_expanded. Both reach IO.console_size and
raise NameError, "wrong constant name console". The reference returns nil
from IO.console outside a TTY. The owner has the reproduction and candidate
hidden-constant API patch. This branch intentionally contains no capi/ diff.

An intermediate build also passed 882/882 corpus programs in both hash modes
in 725.672 seconds, peak family RSS 1193824 KiB, with no resource event. That
precedes the hash-pattern/copy changes; the final 884-program sweep and full
VM/fallback accounting remain required.

## Main integration on November 25

Rebased onto 976bb95d after the bare-name, numeric lookup, native-copy and
extend-hook changes merged. The primitive copy guard now also sees singleton
and private overrides. The one-call native bypass is consumed before copy
hooks, using the upstream copy implementation; there is no second primitive
super-copy path. Corpus 985 and 1017 cover the overlap. Final results must
come from this combined build, not the earlier isolated runtime binary.

The four parameters/browser controls move from 108 MATCH / 12 RED on
30de57d4 to 120 MATCH / zero RED on the pre-integration runtime. The four
permit/required/TestResponse controls move from 72 MATCH / 12 RED to
84 MATCH / zero RED. Full corpus, VM accounting and the two large-file RSS
measurements are being repeated after integration.
