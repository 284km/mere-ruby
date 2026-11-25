# Store anonymous rest arguments in the owning frame

## Cause and representation

Anonymous method rest parameters created an Array on every call, including
empty calls and nested forwarding for which Ruby does not need an Array.
Store synthesized arguments as an immutable native list in the existing
VIcl representation. Its owning frame, including a captured closure, retains
the Ruby values through GC. Named rest parameters remain independent Arrays.
No allocation counter, counting exclusion or dummy Ruby object is added.

The private parameter is `__ar~`; Ruby identifiers and Binding writes cannot
collide with it. Parameter normalization, VM locals, bare super, reflection
and the Proc outer-variable walk preserve its private identity. In particular,
pbase must preserve the tilde instead of aliasing the legal local `__ar`.
Check that private identity only when its marker is encountered; ordinary
parameter names keep the original scan without a per-parameter guard.
Anonymous block parameters retain their existing binding behavior.

Explicit splats and bare super expand native storage. VM Array concatenation
and keyword append materialize ordinary Arrays. Eligible borrowed splats
retain the actual source Array, including frozen state and later mutation.
Direct empty calls and eligible nil splats privately represent Ruby's shared
frozen empty Array as nil. Optional/post signatures that require a new rest
retain synthesized native storage until it is observed.

## Review: shareable Proc isolation

The review reproduction captures anonymous rest through bare super in
Ractor.shareable_proc. The exact private parameter name must contribute to
the outer-variable set. Isolation materializes synthesized rest only when
observed, so rejection reports the ordinary Array and variable '*', rather
than accepting it or exposing a generic internal exception. Existing actual
Arrays retain deep shareability and frozen-state checks. A no-splat empty
call has different reference behavior from an explicit unfrozen empty Array.

The reserved key zero of the existing splat-note map retains source identity;
fixed native slots retain the suffix and original spread lengths. GC follows
a pending positive source handle. Binding consumes the note. Signatures that
can run defaults or destructuring callbacks retain the source in a private
frame slot. A sole anonymous formal has no callback or GC safepoint before
rest installation: a third fixed integer slot transfers provenance only over
that atomic interval, and is reset before installation. This avoids generic
per-call local tuples and temporary frame-map traffic. Native leaf, block,
iterator, sender and Method boundaries consume Array provenance. Idempotent
native deletion already handles an empty table, so cleanup needs no separate
presence probe.

A synthetic native rest needs only its refusal note: skip source-length
walks and fixed-slot writes that only an actual Array or nil can use.
Binding recognizes that refusal before reading the unused source lengths.

Array provenance is not a flagged Hash. Parse keyword formals in this branch
only when the actual trailing Hash has a ruby2_keywords splat note. Borrow
only at the matching positional-prefix boundary, without optional/post or
ruby2_keywords copying; do not compare every Array element.

## Block conversion and ownership

Scope pending Array provenance across block conversion. The existing
temporary iterator root keeps an ephemeral source alive while to_proc or a
block expression can call Ruby and GC. Exceptions remove the scoped state.
A growing-call-count memory probe exposed deleted native root copies retained
in the default arena. Give the existing root table owned storage and include
it in GC churn accounting and compaction. Its only reader finishes during
marking; no borrowed entry survives into compaction. The regression first
accumulates deleted roots with automatic GC disabled, then collects while
an ephemeral conversion source is held, exercising compaction with a live
root as well as marking. This reclaims real
bookkeeping storage without changing Ruby allocation counts.
CRuby compile.c setup_args_dup_rest_p distinguishes a simple block variable
from a complex expression that can modify its splat. Preserve the source
through simple-variable to_proc, but snapshot native argument storage before
a complex block expression. VM splatarray retains its own copy flag.

Common Array, native-list and nil splats keep their existing Val without a
conversion-helper call or reboxing. A live plain block local holding Proc or
nil needs no callback scope; custom to_proc still does. Pseudo variables and
implicit numbered parameters retain the full evaluation path. No ordinary
call receives counting-only work.

## Regression and measurement

Corpus 991 has 56 output lines covering the exact review reproduction,
direct/explicit/frozen/nil/converted splats, deep shareability, source aliasing
across GC, leading/optional/post parameters, repeated splats, local/Binding
collisions, reflection, large arguments, native boundaries, empty super,
keyword append, block conversion mutation, exceptions and ephemeral roots.
All 56 match clean Ruby 4.0.10 on both engines with GC stress 50, including
the live-root compaction regression, with empty stderr. The GC root,
duplicate-definition and dead-definition gates pass on this candidate.
Final-head normal replay, corpus 664, hardware profiles, isolated allocation
file and full corpus/gate results are required before the batched push.

Measure all 76 ruby/test_allocation.rb cases alone on each engine, without
other runtime probes. The main control is 8 MATCH / 68 RED in both modes.
Its atomic differences group into excess rest Arrays (218), excess keyword
Hashes (504), missing CRuby temporary Arrays (198), missing temporary Hashes
(8), and ruby2_keywords copying (28). These are assertion counts, not disjoint
test counts. Generic forwarding and keyword ownership are separate changes.
Record remaining model-specific temporaries as not matched, with the reason;
never allocate unused objects to imitate CRuby's counts.

Post ordinary method/block loops, unchanged so_matrix, anonymous forwarding,
other affected forwarding/proxy profiles, and large-file max RSS before/after.
An instruction regression on every call is not an acceptable allocation fix.
Run corpus --both and the VM corpus (VM/fallback/difference counts), all nine
source gates and record_hygiene. Run one corpus sweep at a time; do not run
the full unit suite or Rails cold measurement. Batch code and records into a
single push after local checks, then read all inline review comments again.

A wider probe found captured optional parameters falsely reported as
reassigned on the main control too. Keep that separate existing Ractor cause
visible rather than changing expected output to hide it.
