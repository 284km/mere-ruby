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
