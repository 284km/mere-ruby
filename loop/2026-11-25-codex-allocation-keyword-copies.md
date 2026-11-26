# ruby2_keywords argument copies and transient keyword state

This branch starts from the merged allocation-accounting work and incorporates
main `66a7afd02bfcde2c512fb686e7584ad556d77de3` before final measurement.
The clean reference is Ruby 4.0.10 at
`a704b7cd95a42cc0cf5f307137bf3aac0285b915`, with 46 default and 38 bundled
gems, zero extras, and Prism 1.8.2. The compiler is
`9dec2ff687a08433247dbdb7729bc19c8522e538` and mgz is
`661a01d8bb68f5acd68e3192bd47f081d179c436`.

## Observable behavior

A flagged nonempty Hash passed through a final splat is copied and unflagged
for an ordinary method, Proc or Lambda without keywords. A directly called marked method
keeps the original; Method#call converts its splat at the native boundary. A marked Proc keeps the original, with or without a
block supplied to its call. The native copy preserves subclass, default or
default_proc, compare_by_identity and ivars; it drops frozen and singleton
state and does not invoke Ruby dup or initialize_copy hooks.

The old unflagging copy lost that Hash state. Procs shared the flagged input
instead of copying it. Method#call also shared it. Block-supplied Proc
calls bypassed the flag policy, lambda marker and captured yield context.
They now prepare these through the same native helpers used without a block.

Method#to_proc uses a private bound-call expression and shared native Method
entry helpers and an internal slot that cannot be a Ruby local, so
singleton or class overrides of public Method#call cannot
replace the captured target. It passes its already-bound argument Array
without a synthetic Ruby splat: a direct positional flagged Hash stays
positional. Incoming flagged splats are converted at the proxy boundary,
before callbacks, and passed blocks retain their original Proc identity.
Captured Ruby definitions and builtin targets keep their existing paths.

The persistent ruby2_keywords flag and a call's temporary keyword origin are
separate properties. Hash.ruby2_keywords_hash and Marshal's flag restoration
set only the persistent flag. A final splat establishes origin for its call.
Binding consumes origin, while nonmutating arity queries can inspect it more
than once. A generic forwarding frame stores its own keyword-origin bit and
restores origin at each forwarding call, including repeated or escaped calls.
A flagged Hash originally passed positionally stays positional through ...;
the permanent flag alone does not determine that frame's provenance. Copies and marked rest arguments keep the appropriate persistent
flag without turning a later direct positional argument into keywords.

## Ownership and cost of call state

Two maps previously recorded empty keywords and final flagged splats. Their
notes could survive a builtin or be consumed by nested argument conversions.
Three native integer slots now record empty keywords, the one final splatted
Hash and a marked Proc's policy. The third slot is valid only while the second
names a Hash. Argument boundaries reset the first two slots; splats publish
after their tail, including block conversion, has finished evaluating.

Block/method binding consumes the note. Body and general VM scope cleanup
also consumes it on normal and exceptional exits, before a direct VM caller
can resume after evaluator code. The slots contain no owners or Ruby values.
No Val constructor, ABI branch, allocation counter or ObjectSpace exclusion
is added. Ordinary method binding skips its former parameter-classification
and argument-tail walks when there is no flagged splat. Final retired
instruction comparisons cover ordinary method/block loops, Proc calls,
marked method/Proc calls without a Hash, keyword calls and the unchanged
Ruby matrix benchmark. A counting-only check on every call is not used.

Corpus 987 compares identity and flags, independent mutation, subclass and
copy state, defaults, callbacks, direct calls after a builtin/empty splat or
exception, native Method/Symbol proxies, nested block conversion, crossing
between evaluator-created methods and VM callers, supplied blocks, lambda
arity and the Proc's captured yield context. Both engines must match the
clean reference before acceptance.

## Remaining allocation differences, grouped by cause

All 76 allocation cases stay in the denominator. The starting main reads
6 MATCH / 70 RED on both engines. Final-head before/after results, exact
remaining atomic counts, and max RSS are posted in the PR description.
The [previous allocation record](2026-11-25-codex-allocation-accounting.md)
contains the complete initial case map; this change resolves actual copy
semantics in its R2K group.

* R2K: direct marked method and marked Proc calls still differ where CRuby allocates an internal
  temporary copy but delivers the original Hash. Preserve the observable
  identity and record the count as not matched; do not create an unused copy.
* A-: CRuby's concatenation/splat temporary Arrays are absent from the native
  Val-list representation. Do not manufacture them solely for a count.
* H-: multiple empty double-splats do not need a merger Hash here. Retain the
  allocation removal from the previous fix and record the count difference.
* A+: anonymous rest and generic forwarding still materialize Ruby Arrays.
  Removing these needs native argument storage with the frame/closure's GC
  lifetime; hiding a real Array in ObjectSpace is not a fix.
* H+: keyword packets and keyword-rest copies are actual Hashes here. Native
  keyword payloads and ownership need separate representation work.
* Literal timeouts: the unchanged 100,000-element child programs exceed their
  existing deadline. They are performance limitations, not observed allocation
  results. The separate large-literal parsing change addresses their causes.

No upstream test, shim, exclusion or budget is changed. No full unit-test
suite or Rails cold measurement is run. Final acceptance uses ordinary O2
builds, the allocation file alone on both engines, the complete corpus with
hash indexing on/off, one subsequent VM corpus, all nine source gates,
record_hygiene, instruction counts and max RSS. Automated inline review
comments are checked after opening the English PR and after every push.

## Review: copy memory, unrelated ivars and native argument consumption

Replace the per-copy temporary map and whole-world ivar walk with an owner
index containing only native ivar names. iv_put maintains the index inside
its existing primitive-ivar branch; removal removes the name, and GC drops
dead Hash owners and compacts the native table. A copy with no ivars never
allocates a scratch map or traverses unrelated objects. The native copy
visits only its source Hash's names and preserves write order.

Leaf native consumers and builtin iterators consume transient splat origin
and its temporary keyword mark before subsequent user code can observe it.
Actual method and Proc forwarding keep their existing argument boundary.
Corpus 987 adds the stale push-to-map case and removed/re-added ivars across
GC. Final-head focused, memory, instruction and full replays are required
before this draft is ready again.

The integrated review build matches all 71 corpus 987 lines on evaluator
and VM under GC stress 50. This also checks a Ruby Array#push override
receiving real splatted keywords; only the terminal native consumer clears
the origin. GC-root, duplicate-definition and dead-definition gates pass.
Current main is merged before all remaining final-head measurements.

## Integrate the CI corrections and current main

Merge main 779c7cc9 after the ERB checker fix in PR 273 and the CI timing
fix in PR 275. The automatic merge retains main's Action Pack and C API
frozen-state changes. Before the next batched push, compare the regression
with clean Ruby on both engines, rebuild in O2, repeat instruction/RSS and
isolated allocation-file comparisons against this main, and replay the full
corpus, VM counts, all source gates and record_hygiene. Keep earlier-head
results identified separately until the integrated head is measured. No
record-only push or full upstream unit suite; serialize corpus sweeps and
run the allocation file alone.

## Resolve the later Hash-mapping iterator entry

Main a9e68981 adds Hash transform_keys mapping conversion at builtin_iter's
entry, the same place this PR consumes transient keyword/splat origin.
Retain both operations: consume this native iterator's incoming origin first,
then normalize mapping arguments. A user to_hash callback must not inherit
an unrelated native consumer's origin. Validate both corpus 987 and main's
941 mapping regression, then take acceptance on this integrated source.
Keep the completed 1a85c934 results separate from the new head's results.

## Re-review: retire origin across every invocation door

The a15ffc1a re-review confirms the two memory findings and Method#to_proc
dispatch fix, but finds native consumers outside prim_method/builtin_iter:
Hash[], Struct.new, instance_variable_set, Kernel#p and evaluator String#%.
Their transient origin must not affect a later positional method, Proc or
lambda call of the same Hash.

Scope incoming splat origin around the shared bare-call, receiver-call,
native-dispatch and supplied-block invocation doors. Keep it until normal
method resolution and argument binding have run, then consume both the
scalar note and the original Hash's temporary keyword mark on return or
exception. A conversion/inspection callback cannot inherit a splat Hash
absent from its own arguments. Primitive leaves and builtin iterators use
the same consumption helper; permanent ruby2_keywords flags are separate.

Extend corpus 987 with every reported native consumer, normal/Proc/lambda
calls after them, exceptions, supplied blocks, native Struct keywords, Ruby
overrides and inspection/name-conversion callbacks. Final acceptance of this
follow-up is pending. Repeat both-engine corpus and allocation comparisons,
all source gates and record_hygiene, dispatch instruction/RSS measurements,
and the requested test_keyword, test_call and test_hash files against the
same main. Measure the allocation file with GC_TIGHT and explicit seed 1.
Do not change upstream tests, exclusions or resource bounds.

Heavy work is admitted through the shared machine queue: at most two heavy
runs across Codex sessions, with existing runs allowed to finish. Queue waits
do not consume test deadlines. This session keeps its corpus sweeps serial
and runs each allocation file alone. Remove merged-PR build/review trees
after preserving their validation records; retain open-PR work and the clean
reference/compiler required by it.

Conversion and lookup callbacks temporarily hide an origin absent from their
own arguments and restore the caller's pending note, keep/empty bits and
keyword-mark value when they return. This lets send's method-name conversion
and Class#new resume the original keyword call, while callback bodies see
ordinary positional arguments. Add sender-conversion and Ruby-initializer
controls before the queued build is admitted.

## Re-review: value splats and native callbacks

The 876ffec8 re-review finds two regressions: value-list splats publish call
origin, and a native callback can bypass the four earlier invocation scopes.
Array literals and multiple assignments now use a value walker that shares
ordinary splat conversion without publishing call notes or removing a flagged
empty Hash. Direct Ruby method entry joins the shared invocation scopes.
Native block callbacks consume the caller's temporary origin at their common
entry; explicit yield and actual argument-forwarding protocols enter the
existing argument-binding path. No list of reported consumer names is added.
Extend corpus 987 with all literal/assignment/interpolation/format shapes,
empty Hash identity, native inspect/to_s/default-block callbacks and explicit
yield, exec and Enumerator::Yielder forwarding controls.

The reviewer also requires finding and fixing any allocation-file RSS
regression, rather than merely disclosing a higher peak. Diagnose the exact
876ffec8 O2 binary in a clean snapshot using external per-case process-family
sampling, GC_TIGHT and fixed seed 1; keep diagnostics separate from official
acceptance. The first paired VM trace changes the relative peaks, so a single
earlier sample does not identify the cause. Attribute the peak to the active
test and its parent/child contributions before deciding on a runtime change.
Do not change upstream cases, exclusions, allocation counters or budgets.
Repeat final-head correctness, dispatch instructions, controlled RSS and all
local corpus/source gates before the next single batched push.

## Integrate current main after the second re-review

Merge main ccb68952 before final acceptance. Resolve lexical yield by keeping
main's define_method/lambda break handling and this branch's argument-forwarding
block entry. Retain the shared native Method call helper and main's new Class
visibility/subclasses handling inside that helper, including its block form.
Main's VM declaration blocks, singleton-contained classes and CGI extension
changes remain in the integrated tree. Replay their focused controls too.

The old-base RSS plan was superseded at an idle phase boundary for this main
integration. Preserve all ten completed samples as partial diagnostic history;
do not label that interrupted plan a five-pair result. Exact child highwaters
identify the 100,000-entry Hash literal as the largest child on both trees:
316,833,792 bytes on main a9e68981 and 317,046,784 on 3a1cd4ac. The observed
short-lived child explains why periodic process-family maxima vary, but does
not establish final integrated resource acceptance. Use a fresh predeclared
five-pair main/head comparison on the integrated build, GC_TIGHT=1, seed 1,
retaining every successful sample, and investigate any persistent increase.
The initial diagnostic with a closed report descriptor is invalid and is
excluded; the corrected observer preserves descriptors and unchanged counts.

The first integrated focused replay catches main's new corpus 1062: the moved
native Method helper still used world-free mod_name_val, losing the displayed
name when Module#name is bound to a class inside an object's singleton. Port
main's mod_name_w world call into that helper. Comparing the complete moved
Method arm with current main, after indentation normalization, finds this as
the only missing dispatch change. Keep corpus 1062 unchanged as the control
and repeat both engines, normal/stress, before continuing acceptance.
The old integrated binary remains pinned for the main/head diagnostic while
this source correction is prepared; rebuild before any final-head result.

## Full-corpus follow-up: empty value-list keyword merges

The f2c40d61 full index ON/OFF sweep finds corpus 117: [**{}] must be [],
where an ordinary splat of a flagged empty Hash retains that Hash. The value
walker now evaluates keyword-merge fields once, omits an empty merge without
publishing empty-keyword or splat origin, and builds a nonempty value using
the existing keyword-merge construction. Ordinary Hash-literal evaluation and
call-argument binding are unchanged. Extend 987 with empty merge positions,
the flagged ordinary-splat control and side-effectful to_hash conversions.

Keep the completed f2c40d61 unit/instruction/RSS evidence identified by that
source. Its controlled 20-run allocation plan retains all samples: median
KiB 675,520 to 617,120 on evaluator, 679,840 to 644,544 on VM. All 76 cases
are COMPLETE on every sample, main 8 MATCH/68 RED and head 14/62. The full
corpus finding prevents accepting that head; final source needs a fresh
focused replay, relevant whole files, controlled allocation/RSS, source gates
and complete corpus/VM acceptance before the batched push.

The first empty-merge focused attempt stopped at reference parsing because
the new test incorrectly placed a positional element after a keyword merge.
Use consecutive empty keyword merges instead; validate syntax with the clean
reference before replay. No runtime comparison from that failed attempt is
acceptance evidence. The successful O2 runtime build is reusable after
verifying that this correction changes only the corpus and this record.

The focused empty-merge cases identify the parser's distinct representation:
arr_hash_items wraps an EHsh in EKwSplat, whereas call/index keyword fields
use EKwHash. The first correction reached only the latter. Handle EKwSplat
explicitly in the value walker: evaluate its value once, omit an empty Hash
and retain a nonempty value without publishing call origin or copying it as
a call packet. Restore ordinary EKwHash value evaluation through EHsh.
The additional cases remain 113 reference lines and cover side-effectful
conversion once. The prior focused failures are not acceptance results.

## Resource diagnosis and the next main integration

Source 9971aa83 passes corpus 987, all 113 reference lines, on both engines
normally and with GC stress 50. All nine focused programs pass in those four
configurations. The complete keyword/call/hash files retain 115/0, 65/0 and
297/1 MATCH/RED on both engines, with no newly failing case IDs. All 76
allocation cases complete: main ccb68952 8/68, head 14/62; every sample keeps
its normal-GC per-case outcomes.

Keep all twenty predeclared GC_TIGHT=1, seed 1 samples. Sampled family RSS
medians in KiB are evaluator 639,808 to 682,656 (+6.70%) and VM 665,968 to
635,472 (-4.58%). The evaluator increase stops final acceptance; no full
corpus, final instruction replay or copy-memory replay is claimed for that
source. Do not substitute earlier favorable medians.

Exact per-process attribution on that source preserves every case outcome.
The largest child is Literal#test_hash_literal, with 100,000 entries.

| Mode | Runner kernel highwater, bytes main to head | Hash-literal child kernel highwater |
| --- | --- | --- |
| evaluator | 416,055,296 to 416,301,056 | 310,968,320 to 310,951,936 |
| VM | 408,829,952 to 415,301,632 | 317,325,312 to 317,112,320 |

Periodic family sampling misses the short child peak: the VM main sample
sees only 132,992 KiB for a child whose kernel highwater is 317,325,312 bytes.
The same diagnostic has a sampled family peak of 574,720 to 758,736 KiB,
although the child kernel highwaters are equal within a page-scale difference.
This establishes sampling loss, not final resource acceptance. The VM runner
single-pair increase still needs repeated measurement. Repeat five alternating
pairs per engine with external kernel counters and no Ruby observer, retaining
both the kernel highwaters and the sampled family metric separately.

A private seven-native equality callback probe finds the same keyword-binding
gap on main and this source, normally and under stress on both engines. It is
a separate shared-main follow-up, not a newly fixed behavior in this PR.

Before that new resource plan starts, a prospective merge finds conflicts
with main 85da98fb. Stop only the still-queued measurement gate under the shared
admission lock; zero executions from that plan have begun. Preserve source
9971aa83 and its verified O2 binary as a diagnostic snapshot. No running file
or another session process is stopped.

Integrate pinned main 85da98fb. Both conflicts duplicate the moved native
Method arms: retain the shared helpers, then port main iv_has flag lookups
and iv_get_or Struct-slot reads into them. A normalized comparison of each
complete moved arm with main is equal after excluding the intentional
argument-origin preparation of this PR. Main scheduler, GC, VM, ivar API,
native module/refinement and corpus changes remain in the integrated tree.

This new integration is unbuilt and has no final acceptance. Use a fresh main
baseline and O2 builds, replay the focused controls and requested whole files,
then the external kernel-counter resource plan. Final copy-memory, instruction,
full corpus/index/VM, source and record gates remain required. Keep every older
result attached to its actual source and retain the original failed RSS plan.
## Asynchronous startup provenance after the invocation scopes

Additional cross-context controls on the frozen 8f0bd866 O2 binary find a
regression before final corpus acceptance: a flagged splat passed to
Thread.new reaches its keyword block as positional after the native creator
returns. Ruby and pinned main return 2; head returns 0, and a keyword lambda
raises. A scheduled Thread must own its startup provenance independently of
the creator's invocation. Save native provenance bits beside its existing
rooted argument Array, restore them after thread-begin callbacks immediately
before binding, and retire them on normal or exceptional completion. No new
Ruby container or work on ordinary method calls is added. Corpus 987 adds
deferred startup across GC, creator positional calls, lambda/start/fork,
marked and ordinary rest blocks, copy metadata and thread-begin callbacks.

The prior source and verified O2 binary/C are preserved in a clean snapshot.
All main85 results remain identified historical evidence, not acceptance of
this new source. Merge main d93de083 before rebuilding; that merge is clean.
The earlier 148 focus comparisons, requested complete upstream files, all
20 kernel-RSS samples and 44 PMU programs were completed, but final corpus
acceptance was not reached and no corresponding completion is claimed.

Resource diagnosis is still open. The largest child is the unchanged
100,000-entry Hash literal; periodic sampling misses its short peak. The
external 20-run plan retains actual runner medians +0.540% evaluator and
+0.436% VM, with nearly identical largest-child highwaters. A subsequent
STORE_STATS=exit diagnostic finds more end-of-test frames/Hash capacity on
evaluator, while VM has fewer captured frames. These values may contain
uncollected garbage; do not claim they prove retained-state equivalence.
STORE_STATS=1 counters from the initial diagnostic run before test/unit's
at_exit and are excluded from post-test retention evidence. Compiler region
statistics from process exit are separate. The planned diagnostic with one
post-test GC stopped at the new Thread control before any allocation-file
run. Its completion marker does not exist. No forced-GC diagnostic RSS may
replace the original acceptance samples or be called a runtime fix.

Repeat fresh source/build identity checks, both-engine normal/stress focus,
the four requested complete upstream files, controlled resource attribution,
copy/ivar and method/block/matrix instruction controls, source gates,
record_hygiene and serial complete corpus/VM sweeps before the next batched
push. The PR remains draft; no new code push or merge readiness is claimed.

The first new-source O2 replay restores ordinary Thread keyword delivery but
finds the supplied marked Proc receives an unflagged Hash. The Thread's new
startup Proc has lost the original Proc's policy. Capture that policy at the
native entry and restore it only for its actual keyword packet. The Thread
roots the supplied Proc until completion and reads its policy at binding,
so marking it after creation but before startup also works across GC; no
process-wide per-Thread map is introduced. Prepare the
unflagged native copy at startup instead of delaying it until binding, so
caller mutation cannot change the queued keyword snapshot. Add a marked
literal-keyword control and mutation-before-join control. Enable the
thread-begin TracePoint without a block so it observes the new thread,
rather than defaulting to the enabling thread only. The failed first replay
and its source/binary identity remain separate; reuse the newly built main
d93 O2 binary only after verifying its exact hash. Rebuild the changed head
before repeating the focused controls and all later acceptance.
