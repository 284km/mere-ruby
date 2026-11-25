# Store anonymous rest arguments as a native frame payload

## Cause and representation

Anonymous method rest parameters always constructed an Array, including an
empty call and an existing input splat that Ruby can borrow. Nested anonymous
forwarding created another Array at each frame. Use an immutable native list
in the existing VIcl representation, held by its owning method frame. A
captured closure retains that frame and GC follows the payload's Ruby values.
A named rest remains an ordinary independent Ruby Array.

The parameter and slot use an internal name containing a tilde. Ruby locals,
named rest parameters and Binding writes with the old implementation spelling
cannot collide with or expose the private native value. Normalize parenthesized
and bare method parameter forms to that same internal name; reflection still
reports an anonymous rest. Anonymous block parameters retain their existing
binding behavior.

## Readers and execution

Explicit argument splats and bare super expand the native list. VM splatarray
can retain it for a borrowed splat and represent a borrowed *nil as an
empty native list; an explicit Array expression still makes
an actual Array. VM array concatenation and keyword-array append materialize
ordinary Arrays instead of inserting the payload as an element or returning
it to Ruby. The existing sole-rest Array sharing optimization does not treat
an anonymous native slot as an Array. No Val tag, registry, counter or counting
exclusion is added. Ordinary method/block calls gain no counting-only work.

Corpus 991 compares forwarding, optional/post parameters, array literals,
keywords, repeated captured forwarding across GC, super with/without a block,
local and named-rest collisions, Binding writes, reflection, ten thousand
arguments, and the Array-free calls Ruby also performs without an Array.
Before claiming success, compare every result with clean Ruby 4.0.10 on both
evaluator and VM in O2 builds.

## Measurement and remaining differences

Post the allocation file measured alone on evaluator and VM before/after,
all 76 cases retained, with cause groups and process-family max RSS. Report
retired instructions for ordinary method/block loops, unchanged Ruby matrix
and anonymous forwarding. Run full corpus --both, one VM corpus with
VM/fallback/difference counts, all nine source gates and record_hygiene.
Run one corpus sweep at a time. Do not run the full unit suite or Rails cold
measurement. Read automated review inline comments after opening and after
every push, and answer or fix Major/P1/P2 before leaving draft.

CRuby sometimes creates an internal rest/concatenation Array that is not
needed by this representation. Record those missing counts as not matched;
do not allocate a dummy Array just to match them. Keyword packets and
keyword-rest copies are separate causes. Generic forwarding uses the same
lifetime principle in its independent change; integrate the shared native
readers without weakening either regression corpus.

## Review: captured rest isolation and borrowed Array provenance

The private anonymous name contains a tilde, which pbase normally strips
from renamed locals. Preserve that exact private name when bare super
contributes a method's parameters to a Proc's outer-variable set. Otherwise
isolation never sees the captured rest at all. Materialize a synthesized
native rest only when isolation observes it, so its error names an ordinary
Array instead of leaking an internal value or a generic StandardError.

Retain the source Array of an eligible anonymous splat, including its frozen
state and later mutations. A reserved non-handle slot in the existing splat
note table carries source identity; one fixed native integer slot holds the
suffix length. The existing nonempty-note binder branch snapshots the actual
source value in a private frame slot before defaults may call Ruby.
The collector follows a pending source handle. Binding consumes the note and
removes the frame metadata when the anonymous rest is installed. Native leaf,
block, iterator, sender and Method boundaries consume Array provenance.
Ordinary fixed-arity Ruby calls do not gain a counting-only branch.

An empty direct rest, and an eligible borrowed nil splat, represent Ruby's
frozen shared empty Array privately as nil. An explicit empty Array splat
retains that actual Array; an unfrozen one must refuse isolation. Optional or
post-rest binding that synthesizes an Array keeps an unshareable native list
until observed. VM borrowed to_a conversion uses the same source conversion
helper as the evaluator, preserving a frozen converted Array rather than
copying it. Array-producing operations still materialize normal Arrays.

Corpus 991 now has 47 output lines, including the exact singleton-method
review reproduction, direct/explicit/frozen/nil and converted splats, deep
shareability, leading/post parameters, repeated splats, native Method/send
boundaries, retained source aliasing across GC, empty super and keyword Array
append. All lines match clean Ruby 4.0.10 on evaluator and VM under GC stress
50. Existing corpus 664's 27 lines match both engines as well. GC-root,
duplicate-definition and dead-definition gates pass. Final-head hardware,
whole allocation-file and complete corpus replays follow before readiness.

A wider probe also found an existing main difference for captured optional
parameters: a defaulted parameter can be falsely reported as reassigned by
Ractor isolation. The same refusal reproduces on the pre-change main control;
that separate reassignment cause is not hidden by changing expected output
in this regression corpus. No unused Ruby Array is allocated to imitate an
allocation count.

The first review fix passed semantic checks but added instructions to the
borrowed-rest loop, especially on the VM. Replace three map entries and a
boxed metadata list per splat with one existing-table slot and one fixed
native integer slot. Store the actual source value in the frame, rather than
boxing its id and lengths in another list. All 47 regression output lines
still match both engines with GC stress 50; the three source gates pass.
Repeat the hardware measurement before claiming that the performance issue
is resolved. No allocation counter or unused Ruby object changes.
