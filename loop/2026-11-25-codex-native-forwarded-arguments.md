# Store generic forwarded arguments in the owning frame

This branch started from main
`2e402b9422018f27ba5cc96a9a6ae797bcd22e8a`. Final measurement follows a merge
of current main `d03cbb8371a10da6c974969606018eb91af60c84`, which includes
the literal parser fix. Allocation-file RSS can therefore be compared with
completed literal cases instead of timed-out child processes. The reference is clean Ruby
4.0.10 at `a704b7cd95a42cc0cf5f307137bf3aac0285b915`: 46 default and 38
bundled gems, zero extras, Prism 1.8.2. Compiler
`9dec2ff687a08433247dbdb7729bc19c8522e538` and mgz
`661a01d8bb68f5acd68e3192bd47f081d179c436` are pinned for O2 measurement.

## Representation and lifetime

A method's `...` is private argument storage, but binding it previously
created a Ruby Array even when the method returned without forwarding it.
A chain of forwarding methods created another such Array in each frame.
The allocation file's argument_forwarding and nested_argument_forwarding
cases expose these actual extra objects.

Use the existing internal native-list Val form for this immutable payload.
The frame Map copies the list into its own storage. Its normal recycling
reclaims the list; a captured frame's existing compaction retains it for
its Proc or Binding. There is no new registry, root table, Val tag or
cleanup branch on ordinary calls. GC follows the list's Ruby values only
when an owning frame/closure is reached. Explicit splats and bare super
read the same native values, and a target's named rest still creates the
real Ruby Array its program can inspect and mutate.

The internal parameter marker and physical frame slot use __fwd~args,
whose tilde makes it inaccessible
as a Ruby local name. The parser and VM use this slot internally. A user's
__fwd local or Binding write cannot replace the forwarded data, and
Binding#get cannot publish the internal list. Reflection continues to
report Ruby's anonymous parameters; the native slot is not a Ruby local.
The parser's forbidden-forwarding check and hidden-for-variable check use
the same internal name.

Corpus 989 compares plain/nested/prefixed forwarding, keywords, blocks,
super, repeated escaped-closure calls across GC, independent later frames,
evaluator-defined methods called by the VM, local-variable reflection,
Binding access, user-local collisions, a real named __fwd rest parameter,
parameter reflection, Fiber resumption, a 10,000-argument call, exception
cleanup and named-rest mutation. All 22 output lines match clean Ruby on
both final O2 engines. Its final
allocation window is only an empty forwarding call after setup, for which
Ruby creates zero Arrays. This removes a real Array, rather than hiding
one from ObjectSpace or manufacturing CRuby compiler temporaries.

## Acceptance and remaining causes

The complete cause map is in
[the allocation record](2026-11-25-codex-allocation-accounting.md).
This change addresses A+ for generic forwarding. Named rest parameters
remain observable Ruby Arrays. Anonymous rest and keyword packets are
separate representation work. Missing CRuby-only concatenation/splat
Arrays, empty-merge Hashes and unobservable marked-method/Proc Hash copies
stay documented as not matched; they are not synthesized for a count.
The parser change now on the comparison main handles the two large-literal timeouts.

Measure ruby/test_allocation.rb alone on both evaluator and VM, before and
after against the final comparison main above. Retain all 76 cases, budgets and
exclusions unchanged and report MATCH/RED, atomic cause groups and max RSS
in the English PR. Instruction comparisons include method/block loops,
the unchanged Ruby matrix benchmark, and positional/keyword forwarding
loops. No counting-only work is added to every call. Final-head gates,
record_hygiene, the full corpus with both hash-index modes and the VM
corpus run in sequence, one corpus sweep at a time. No full unit suite or
Rails cold measurement is run. Read automated inline comments after the
PR is opened and after each push.

The forwarding marker overlaps the origin-state change in PR 242. After
one of those PRs merges, merge current main into the remaining branch and
reconcile both the private native slot and the saved keyword-origin bit.
Retain both corpora when validating that integrated tree.
