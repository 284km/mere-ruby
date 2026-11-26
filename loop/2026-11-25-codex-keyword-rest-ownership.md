# Reuse fresh keyword packets for a pure keyword rest

## Cause and scope

Calling a Ruby method, Proc or Lambda with only a named **kwargs parameter
created a caller Hash and copied it into a second callee Hash. A completed,
fresh keyword packet can itself become the named keyword rest. The original
Hash supplied through **input remains independent: the call-site producer
already copied it. An empty call still creates the observable callee Hash.

Use the existing keyword-origin map: VNil means borrowed origin, VBool true
permits reuse of a completed fresh packet. No root, counter or Val tag is
added. Keyword binding consumes origin. Generic forwarding downgrades the
packet to borrowed state and records its provenance in its frame, because
multiple or escaped forwarding calls need independent keyword-rest Hashes.
Calls with explicit named keywords retain their copy: dropping keys before
binding defaults needs a separate lifetime argument for the removed values.

## Exposure and lifetime

ObjectSpace enumeration downgrades a completed packet before publishing its
handle. If block conversion exposes a packet before binding, the target gets
an independent Hash, as on Ruby. Positional defaults run after keyword-rest
binding and may observe that bound Hash. Hash-key callbacks during packet
construction are different: Ruby may expose and deliver the same Hash. Fresh
permission is published after seeding, so that case retains the reference
identity. Permission describes a completed call packet, not absence of every
possible alias during its construction.

The returned Hash is an ordinary GC-managed Hash in the target frame and in
any captured closure. Captured values and later mutations keep their normal
GC and identity behavior; no counting exclusion hides a live object.

## Validation and remaining groups

Corpus 994 covers method/Proc/Lambda copies, subclasses and copy hooks,
repeated forwarding with mutation, explicit-keyword fallback, positional
reuse, captured values across GC, nested conversion, actual Hash counts,
ObjectSpace exposure at conversion and default binding, and custom-key
callbacks during construction. Compare both engines with clean Ruby 4.0.10.

Keep all 76 allocation cases and existing budgets/exclusions. Post the
allocation file measured alone, evaluator and VM before/after, grouped
atomic mismatches, max RSS, hardware instructions for method/block/matrix
and keyword-rest calls, full corpus --both, VM/fallback/difference counts,
all nine source gates and record_hygiene in the English PR description.
No full unit-test suite or Rails cold measurement is run. Run one corpus
sweep at a time and read automated inline review comments after each push.

This removes a real redundant Hash. Remaining fixed-keyword call packets,
anonymous rest Arrays, and generic forwarding are distinct representation
work. CRuby-only concatenation/splat temporaries, missing empty-merger Hashes
and unused marked-call copies stay documented as not matched; never create
an unused Ruby object solely to imitate a count.

## Review: repeated implicit super

A callee consumes transient keyword origin, including a packet borrowed from
an enclosing generic forwarding frame. Restore that frame's saved origin
when zsuper_args expands its private forwarding rest, at every bare-super
boundary. Restored packets stay borrowed, so separate callee keyword rests
retain independent Hash identities. This touches only the existing rest
expansion path, with no extra work on ordinary fixed-arity calls.

Corpus 994 adds consume-then-super and repeated bare super, including an
identity check for the two returned Hashes. All 19 output lines match clean
Ruby 4.0.10 on evaluator and VM, also with GC stress 50. GC-root, duplicate
definition and dead-definition gates pass. Previous whole-file allocation
results are historical until replayed on this review fix; final whole-file,
corpus and hardware measurements will be posted in the PR description.

## Current-main integration and corpus number

Merge main 779c7cc9 after the CI integrity fixes and the Action Pack/C API
changes. Main now uses corpus 989 through 992 for other regressions; move
this unmerged program from 990 to the free slot 994. Its descriptive
filename and assertions are unchanged. Repeat focused comparisons on both
engines, isolated allocation-file before/after totals, instruction/RSS
controls, all corpus modes, source gates and record_hygiene against this
main before the next batched code-and-record push. Earlier head results
remain historical until the integrated head is measured. One corpus sweep
at a time; no full unit suite or Rails cold measurement.

## Follow the iterator-mapping integration

Merge main a9e68981 for the same acceptance baseline as PR 242. Preserve
main's Hash mapping conversion before iteration and this change's native
argument ownership. For anonymous rest, consume incoming Array provenance
before any mapping to_hash callback. Validate the integrated regression and
main's mapping corpus before recording final-head acceptance; earlier
779c7cc9 measurements retain their exact revision labels.

## Current-main integration before final acceptance

Integrate main ecd65075, retaining its lexical block/super behavior, singleton
metadata collection, formatter changes, C API transfer work and monotonic
clock. Rebuild in O2 and repeat the isolated allocation file on both engines
against this same main, ownership/bare-super and mapping regressions,
call/block/matrix and keyword-rest instructions, full corpus ON/OFF, VM
counts, source gates, record_hygiene and large-file RSS. Earlier a9e68981
measurements remain historical. Shared admission limits heavy jobs across
Codex sessions to two; serialize this session's corpus sweeps and isolate
allocation files. Batch integration, code and records in one validated push.
The saved origin and private forwarding payload still need reconciliation
when PR 242/245 meets this independently measured branch.

## Integrate the keyword-copy review corrections

Merge local PR 242 source f2c40d61 on current main ccb68952 before the next
validation. Keep its value-list/call-origin separation and native callback
entries, its world-aware native Method helper, and this branch's fresh packet
marks, borrowed forwarding state and keyword-rest ownership transfer. Bare
super keeps restoring the saved forwarding-frame keyword provenance.

A block binder acquires the actual callee keyword-rest value before a default
can call Ruby, then consumes the incoming origin before that callback. It
binds the already acquired rest at its original validation point. This keeps
the ownership optimization and PR 242's positional-Hash rule together; no
packet is exposed to Ruby with a stale keyword mark. Add Proc/lambda default
callbacks with the incoming flagged Hash to corpus 994.

This combined source is local, unbuilt and unaccepted. Replay corpus 987 and
994 normally/under GC stress on both engines, the complete allocation file
alone, all source gates/record hygiene, corpus index ON/OFF then VM, instructions
and controlled large-file RSS. Treat PR 242 as a dependency until it is merged;
do not relabel the earlier independent-head results as integrated acceptance.

Integrate parent source 8f0bd866 and main 85da98fb without manual conflict
resolution. Preserve the early block keyword-rest acquisition and incoming
origin retirement, plus the complete Method ivar API port and new main
runtime changes. The parent focused controls pass; this combined ownership
source remains unbuilt and needs its own complete validation before a push.
Only source and git work takes place during parent allocation measurements.
