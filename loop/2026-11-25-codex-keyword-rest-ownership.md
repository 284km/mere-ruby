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

Corpus 990 covers method/Proc/Lambda copies, subclasses and copy hooks,
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
