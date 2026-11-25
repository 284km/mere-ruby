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
