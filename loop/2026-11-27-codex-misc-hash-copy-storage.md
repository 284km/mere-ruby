# A1: Hash copy/replace storage

Branch from current origin/main 410c231433bebbc3a3f243289c6e2b9d2f0a888c.
Reference: clean Ruby 4.0.10 through tools/ref_ruby.sh. Record the storage
cause and proposed invariants before changing code.

| Original RED | Verified cause component | Required behavior |
| --- | --- | --- |
| test_hash.rb test_replace_memory_leak | Each dup copies all pair cells and constructs an index; replace immediately copies the same cells again. The original has 676 keys and 500,000 dup/replace iterations, after 10,000 warmup dups. | Keep the original 10-second limit and all memory assertions; do not infer a leak from its timeout. |

Use an immutable internal pair snapshot, shared between hashes, with each
hash retaining its own identity, defaults, compare mode, ivars and mutation
state. A source or destination write publishes independent pair storage;
no writable index or pending queue is shared. Snapshot Arrays use the
existing metadata representation, hidden from ObjectSpace enumeration,
counts and _id2ref, and are rooted from the owning Hash during GC.
Dead owners must release their snapshot association during the sweep;
the association map must be compacted and count toward allocation pressure.

Lazy index creation must preserve the digest taken when a mutable key was
stored. Sharing will therefore require immutable plain keys, using the
existing hplain_key classification, and ordinary comparison mode. Small
hashes retain the existing hplain_small compact-list representation. Mutable
or custom container keys and identity-mode hashes keep their existing
eager-copy path. Lazy rebuilding over an immutable plain-key snapshot is
safe; rebuilding later over a changed Array key would be a regression.

First settle actual pending appends and overwritten values into a snapshot.
Reuse a snapshot only while that state remains current. Central pair-store
writers detach the owner; per-owner pending queues and indexes remain
independent. Copying defaults and subclass/singleton/initialize_copy behavior
continues through the existing native dispatch. Self replace must retain
its identity mode and default proc without discarding source metadata.

Corpus 1137 is reserved for source/destination mutations, pending and stale
values, replacement chains, GC lifetimes, mutable-key fallbacks, defaults,
identity, subclasses, clone/freeze and iteration behavior. Compare unchanged
related Hash test selections and the original resource case with a matching
main build, evaluator and VM, fixed --seed=1 and tight-GC RSS. Report costs
before/after, run both complete corpus sweeps and source/completed-record
gates. No full unit/Rails suite, workflow change or reference gem install.

## R1 corpus failure and R2 fixture scope

The initial evaluator and VM full sweeps both exited 1 at corpus 1137 with
MERE_RUBY_NO_HASH_INDEX=1. They are failed attempts, not complete passes.
The mutable Array key lookup control exposes an existing index-off difference:

```ruby
key = [:before]
source = {key => :stored}
copy = source.dup
key << :after
p [source[key], copy[key]]
source.rehash
p [source[key], copy[key]]
```

Clean Ruby answers [nil, nil], then [:stored, nil]. Main 410c2314 and this
candidate agree with Ruby on both engines with indexing enabled; with indexing
disabled, both answer [:stored, :stored] twice. All eight main/candidate
configurations were measured. This pre-existing read-door difference remains
open; this copy-storage change does not claim to repair it. The eager fallback
retains the existing stored digest rather than rebuilding a mutable-key index.

Corpus 1137 now checks that the same mutable key is retained by both owners,
explicitly rehashes both, and verifies independent values after a copy write.
It continues to exercise the eager mutable-key fallback, without asserting a
repair of the separate index-off lookup gap. Its 22 rows match the reference in
all four evaluator/VM and index ON/OFF configurations. Main differs only in the
identity-mode self-replace case fixed by this branch.

The runtime, O2 binary, original CRuby selections and cost benchmark are
unchanged. R2 reuses their exact SHA-checked measurements and reruns the full
corpus pair with the revised fixture. Original resource counts, timeout and
memory assertions are unchanged. See the final acceptance section for both
full-sweep outcomes.

## Completed R2 acceptance completed acceptance

Large Hash dup/clone and replace share an immutable private pair snapshot for ordinary
hashes with immutable plain keys. Every owner retains independent defaults, identity,
ivars, index, pending queue and mutation state; central pair writes detach the owner.
Small hashes, mutable/custom keys and identity-mode hashes keep their eager-copy path,
preserving stored key digests. Private metadata Arrays are hidden from ObjectSpace and
marked only through their owning hashes; dead associations are swept/compacted and count
toward GC pressure. Self-replace and initialize_copy/subclass behavior remain on the
existing dispatch paths.

Fresh local acceptance uses clean Ruby 4.0.10 through tools/ref_ruby.sh. The two full
sweeps use the same freshly built O2 candidate, with hash indexing ON and OFF.

- `sh run_corpus.sh --both`: **995/995 PASS**, exit 0.
- `MERE_RUBY_VM=1 sh run_corpus.sh --both`: **995/995 PASS**, exit 0.

Focused corpus 1137 matches the reference on both engines (stdout, stderr and exit
status). Related original CRuby selections are run unchanged, one file at a time,
against the exact matching main 410c2314. Every invocation uses `MERE_RUBY_GC_TIGHT=1`
and parsed `--seed=1`. The selected test counts below do not claim whole-file or
full-suite passes.

| Original selection | Ruby 4.0.10 | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | --- | --- | --- | --- | --- |
| ruby/test_hash.rb (36 selected) | 36 / 161 PASS | 36 / 161 PASS | 36 / 161 PASS | 36 / 161 PASS | 36 / 161 PASS |
| ruby/test_hash.rb (1 selected) | 1 / 3 PASS | 1 / 0, 0 failures, 1 errors | 1 / 3 PASS | 1 / 0, 0 failures, 1 errors | 1 / 3 PASS |

RSS values below are measured maximum resident set sizes of the test driver from
`/usr/bin/time -l`, in bytes.

| Max RSS bytes, same selections | Reference | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: | ---: |
| ruby/test_hash.rb (36 selected) | 23363584 | 170328064 | 169099264 | 183812096 | 186925056 |
| ruby/test_hash.rb (1 selected) | 86130688 | 169558016 | 167985152 | 183926784 | 184844288 |

Cost measurements use three alternating main/candidate O2 pairs, tight GC and parsed
--seed=1. Instructions and elapsed seconds are medians; RSS is the maximum of three
runs. Elapsed time is diagnostic under shared-machine load.

| Workload / engine | Instruction change | Main / candidate median seconds | Main / candidate max RSS bytes |
| --- | ---: | --- | --- |
| large_dup / evaluator | -90.927% | 1.255334 / 0.111610 | 109068288 / 74825728 |
| large_replace / evaluator | -92.929% | 1.505843 / 0.137537 | 99434496 / 75563008 |
| small_dup / evaluator | +0.445% | 0.109559 / 0.110096 | 80576512 / 80379904 |
| read / evaluator | +0.009% | 0.365282 / 0.345390 | 75350016 / 75137024 |
| write / evaluator | +0.240% | 0.117248 / 0.121769 | 72957952 / 72941568 |
| large_dup / VM | -90.306% | 1.105137 / 0.131783 | 110067712 / 76169216 |
| large_replace / VM | -92.630% | 1.504051 / 0.132600 | 100597760 / 76972032 |
| small_dup / VM | +0.511% | 0.110987 / 0.111823 | 81330176 / 81543168 |
| read / VM | +0.037% | 0.344652 / 0.354380 | 76627968 / 76414976 |
| write / VM | +0.324% | 0.110517 / 0.115632 | 74301440 / 74121216 |

Candidate O2 SHA-256:
`7bc1c83b03cf54bb7d6af80d7f97ba39884aa2d8eefd89ef334274fe36a92003`. Matching-main
control: 410c231433bebbc3a3f243289c6e2b9d2f0a888c. Compiler 9dec2ff6, mgz 661a01d8.

Original ruby/test_hash.rb test_replace_memory_leak is unchanged: 676 keys, 10000 warmup
dups, then 500000 dup/replace iterations under its original 10-second resource budget
and memory assertions. Reference and candidate evaluator/VM all pass 1 test / 3
assertions; matching main times out on both engines. Corpus 1137 has 22
reference-matched rows covering storage cutoffs, source/destination writes,
pending/stale values, defaults/ivars, shallow values, GC lifetime,
identity/self-replace, mutable-key rehash fallbacks, frozen clone, subclass hooks and
iteration. Benchmarks use 10000 operations, except 100000 ordinary reads; none weakens
the original resource case.

The small-hash eager path retains snapshot-eligibility and detach checks; its measured
instruction cost is reported above. Large immutable-key copies avoid rebuilding the pair
cells and index. No zero-overhead claim is made.

The initial full evaluator and VM attempts both exited 1 at the new mutable-key lookup
control with MERE_RUBY_NO_HASH_INDEX=1. Separate comparisons establish the same
divergence on the matching main and candidate, on both engines: a mutated Array key
remains findable in index-off scan mode, unlike Ruby. This existing gap remains open.
Corpus 1137 now retains the shallow mutable-key check and explicitly rehashes both
copies before checking independent writes; it does not assert a repair of that separate
lookup issue. The complete original reproduction and failed-attempt disposition are
retained in the loop note. The revised 22 rows match all four candidate engine/index
configurations; matching main differs only in identity-mode self-replace. Runtime input
hashes and binary SHA are unchanged, so the original CRuby/resource and three-pair cost
measurements are reused exactly; both complete corpus sweeps below are fresh R2 retries.
No original upstream test, assertion or resource budget was changed.

Source gates (gc_roots, dup_defs, dead_defs, meth_writes, name_spec, rx_caps, ns_names,
name_len, plus iv_door where present), generated-C bracket depth, full/explicit
completed record_hygiene and staged/unstaged whitespace: PASS. Code/integration and the
completed loop record are pushed together. No full unit/Rails suite, reference gem
installation or workflow change.
