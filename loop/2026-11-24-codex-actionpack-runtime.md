# Action Pack: runtime contracts and complete suite accounting

Work in progress, based on current main 30de57d4. Rails is the unchanged
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
  Walking prunes subtrees outside the location's line.
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

Corpus 1000-1014 contains focused regressions. Before the first four-digit
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
