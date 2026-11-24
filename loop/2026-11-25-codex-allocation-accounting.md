# Allocation accounting and the Ruby 4.0.10 allocation tests

The branch starts from main `bab971fc` and incorporates main `6d62be02`
(including the native ISeq loader changes in #226) before final measurement.
The reference is a clean Ruby 4.0.10, source revision
`a704b7cd95a42cc0cf5f307137bf3aac0285b915`: 46 default and 38 bundled gem
specifications, no extra gems, and Prism 1.8.2. No reference gems were installed.

## Fixes

* Parameter-name Arrays cached for method frames are interpreter metadata.
  Classify them once on a cache miss and exclude them from public ObjectSpace
  Array counts, enumeration and ID lookup. The integer classification map is
  not an owner or a GC root; prune it after Array sweep. Cached ordinary calls
  keep exactly the existing path, without an additional lookup or check.
* Evaluate keyword pairs before constructing a Ruby Hash. If the pairs are
  empty, preserve the existing empty-keyword note without constructing a Hash
  that would immediately be discarded. Conversion callbacks still execute;
  nonempty keyword Hashes retain their existing copy and marking behavior.
* Allocate ObjectSpace.count_objects' public result Hash before its private
  scratch-allocation interval. The returned user-visible Hash must remain
  counted; reusing a supplied Hash still allocates no result Hash.

Corpus 986 covers cold method metadata, public Array enumeration, empty
keywords and keyword-rest arguments, the public result Hash, conversion side
effects, nonempty keyword isolation, and GC with alias/redefinition/super.
No upstream tests or shims are changed. GC.stat's existing native issued-handle
allocation counter is unchanged; this fixes public Array/Hash accounting.

## Scope and remaining differences

Run only `ruby/test_allocation.rb` through `unittest/run.sh`, separately on the
evaluator and VM. All 76 cases remain in the denominator; no exclusions or
increased budgets are used. Starting-main development runs read 0 MATCH /
76 RED on both engines; the fixes read 6 MATCH / 70 RED. Exact final-head
results against the incorporated main, resource use and hardware instruction
counts are posted in the PR description.

The six repaired whole tests are the three named-rest forms
`test_positional_splat_parameter`, `test_required_and_positional_splat_parameters`
and `test_positional_splat_and_post_parameters`, in MethodCall and its WithBlock
subclass. Atomic assertion differences fell from 1341 to 956: 393 disappeared,
8 newly differ, and 70 remaining comparisons have a closer actual count.

The following cause groups overlap; affected-case counts must not be summed.
The per-case table below accounts for all 76 tests on each engine. "Not matched"
means the representation change is outside this bookkeeping fix, or would
require manufacturing Ruby objects solely to imitate CRuby's count. It is not
an exclusion or a claim that every remaining RED is inherently unfixable.

| Code | Atomic differences | Affected RED cases | Cause and disposition |
| --- | ---: | ---: | --- |
| A- | 198 | 40 | Not matched: CRuby creates positional splat/concatenation temporary Arrays; the evaluator uses native Val lists. Do not manufacture Ruby Arrays just for the counter. |
| A+ | 218 | 10 | Not matched: anonymous rest and generic forwarding materialize Ruby Arrays here; CRuby can borrow stack arguments. Eliminating these requires argument representation/ownership work. |
| H+ | 504 | 38 | Not matched: keyword packets and keyword-rest copies use real Hash values here; CRuby can use fixed keyword slots and ownership transfer. Hiding these real Ruby values would be false accounting. |
| R2K | 28 | 16 | Not matched: ruby2_keywords flag-clearing/copy temporaries differ from the native mark-table protocol. Requires ownership/representation work, not an artificial Hash allocation. |
| H- | 8 | 4 | Not matched: merging multiple empty double-splats no longer creates a discarded Hash; CRuby creates one internal merger Hash. This deliberately removes work and is reported as newly unmatched. |
| T | n/a | 2 | Existing performance limitation: the two 100,000-element literal child programs time out. Their allocation result is unobserved; do not label these CRuby object-model differences. |

Before and after both include the literal timeouts. Remaining runtime results
are 68 assertion failures and two errors, against 76 passing reference tests.

| Test (`TestAllocation::` prefix omitted) | Result / causes, evaluator and VM |
| --- | --- |
| `Literal#test_array_literal` | T |
| `Literal#test_hash_literal` | T |
| `MethodCall#test_anonymous_splat_and_anonymous_keyword_splat_parameters` | A+, H+ |
| `MethodCall#test_anonymous_splat_parameter` | A+ |
| `MethodCall#test_argument_forwarding` | A+, H+ |
| `MethodCall#test_keyword_and_keyword_splat_parameter` | A-, H+ |
| `MethodCall#test_keyword_parameter` | A-, H+ |
| `MethodCall#test_keyword_splat_parameter` | A-, H+ |
| `MethodCall#test_nested_anonymous_splat_and_anonymous_keyword_splat_parameters` | A+, H+ |
| `MethodCall#test_nested_argument_forwarding` | A+, H+ |
| `MethodCall#test_no_array_allocation_with_splat_and_nonstatic_keywords` | A- |
| `MethodCall#test_no_parameters` | A-, H- |
| `MethodCall#test_optional_parameter` | A- |
| `MethodCall#test_positional_splat_and_keyword_parameter` | H+ |
| `MethodCall#test_positional_splat_and_keyword_splat_parameter` | H+ |
| `MethodCall#test_positional_splat_and_post_parameters` | MATCH |
| `MethodCall#test_positional_splat_parameter` | MATCH |
| `MethodCall#test_required_and_keyword_splat_parameter` | A-, H+ |
| `MethodCall#test_required_and_positional_splat_parameters` | MATCH |
| `MethodCall#test_required_parameter` | A- |
| `MethodCall#test_required_positional_and_keyword_parameter` | A-, H+ |
| `MethodCall#test_ruby2_keywords` | R2K |
| `MethodCall::WithBlock#test_anonymous_splat_and_anonymous_keyword_splat_parameters` | A+, H+ |
| `MethodCall::WithBlock#test_anonymous_splat_parameter` | A+ |
| `MethodCall::WithBlock#test_argument_forwarding` | A+, H+ |
| `MethodCall::WithBlock#test_keyword_and_keyword_splat_parameter` | A-, H+ |
| `MethodCall::WithBlock#test_keyword_parameter` | A-, H+ |
| `MethodCall::WithBlock#test_keyword_splat_parameter` | A-, H+ |
| `MethodCall::WithBlock#test_nested_anonymous_splat_and_anonymous_keyword_splat_parameters` | A+, H+ |
| `MethodCall::WithBlock#test_nested_argument_forwarding` | A+, H+ |
| `MethodCall::WithBlock#test_no_array_allocation_with_splat_and_nonstatic_keywords` | A- |
| `MethodCall::WithBlock#test_no_parameters` | A-, H- |
| `MethodCall::WithBlock#test_optional_parameter` | A- |
| `MethodCall::WithBlock#test_positional_splat_and_keyword_parameter` | H+ |
| `MethodCall::WithBlock#test_positional_splat_and_keyword_splat_parameter` | H+ |
| `MethodCall::WithBlock#test_positional_splat_and_post_parameters` | MATCH |
| `MethodCall::WithBlock#test_positional_splat_parameter` | MATCH |
| `MethodCall::WithBlock#test_required_and_keyword_splat_parameter` | A-, H+ |
| `MethodCall::WithBlock#test_required_and_positional_splat_parameters` | MATCH |
| `MethodCall::WithBlock#test_required_parameter` | A- |
| `MethodCall::WithBlock#test_required_positional_and_keyword_parameter` | A-, H+ |
| `MethodCall::WithBlock#test_ruby2_keywords` | R2K |
| `ProcCall#test_anonymous_splat_and_anonymous_keyword_splat_parameters` | A-, H+ |
| `ProcCall#test_anonymous_splat_parameter` | A-, R2K |
| `ProcCall#test_keyword_and_keyword_splat_parameter` | A-, H+ |
| `ProcCall#test_keyword_parameter` | A-, H+ |
| `ProcCall#test_keyword_splat_parameter` | A-, H+ |
| `ProcCall#test_no_array_allocation_with_splat_and_nonstatic_keywords` | A- |
| `ProcCall#test_no_parameters` | A-, H- |
| `ProcCall#test_optional_parameter` | A-, R2K |
| `ProcCall#test_positional_splat_and_keyword_parameter` | H+ |
| `ProcCall#test_positional_splat_and_keyword_splat_parameter` | H+ |
| `ProcCall#test_positional_splat_and_post_parameters` | R2K |
| `ProcCall#test_positional_splat_parameter` | R2K |
| `ProcCall#test_required_and_keyword_splat_parameter` | A-, H+ |
| `ProcCall#test_required_and_positional_splat_parameters` | R2K |
| `ProcCall#test_required_parameter` | A-, R2K |
| `ProcCall#test_required_positional_and_keyword_parameter` | A-, H+ |
| `ProcCall#test_ruby2_keywords` | R2K |
| `ProcCall::WithBlock#test_anonymous_splat_and_anonymous_keyword_splat_parameters` | A-, H+ |
| `ProcCall::WithBlock#test_anonymous_splat_parameter` | A-, R2K |
| `ProcCall::WithBlock#test_keyword_and_keyword_splat_parameter` | A-, H+ |
| `ProcCall::WithBlock#test_keyword_parameter` | A-, H+ |
| `ProcCall::WithBlock#test_keyword_splat_parameter` | A-, H+ |
| `ProcCall::WithBlock#test_no_array_allocation_with_splat_and_nonstatic_keywords` | A- |
| `ProcCall::WithBlock#test_no_parameters` | A-, H- |
| `ProcCall::WithBlock#test_optional_parameter` | A-, R2K |
| `ProcCall::WithBlock#test_positional_splat_and_keyword_parameter` | H+ |
| `ProcCall::WithBlock#test_positional_splat_and_keyword_splat_parameter` | H+ |
| `ProcCall::WithBlock#test_positional_splat_and_post_parameters` | R2K |
| `ProcCall::WithBlock#test_positional_splat_parameter` | R2K |
| `ProcCall::WithBlock#test_required_and_keyword_splat_parameter` | A-, H+ |
| `ProcCall::WithBlock#test_required_and_positional_splat_parameters` | R2K |
| `ProcCall::WithBlock#test_required_parameter` | A-, R2K |
| `ProcCall::WithBlock#test_required_positional_and_keyword_parameter` | A-, H+ |
| `ProcCall::WithBlock#test_ruby2_keywords` | R2K |

## Performance and acceptance procedure

The parameter metadata change adds work only on the cache-miss path and in
ObjectSpace/GC operations. The keyword change removes an allocation; it adds
no tracking to ordinary calls. A proposed extra Val variant was rejected
because copying frames would add a tag/region branch on every call.

Use the pinned Mere compiler `9dec2ff687a08433247dbdb7729bc19c8522e538`,
mgz `661a01d8bb68f5acd68e3192bd47f081d179c436`, ordinary O2 builds on
both trees, and a fixed binary throughout each measurement. Compare retired
hardware instructions with `/usr/bin/time -l` for method and block loops at
100,000 and 200,000 iterations, the unchanged Ruby `benchmark/so_matrix.rb`
(60 iterations, size 40), and empty/nonempty keyword loops. Include raw counts
for both engines; elapsed time is not the call-path cost criterion.

Final acceptance includes the full corpus with hash indexing on and off,
then the full VM corpus (VM/fallback/difference counts), all nine source gates,
and record_hygiene. Run one corpus sweep at a time. Record before/after
process-family max RSS for the allocation file, with all child programs and
the unchanged test budgets. No full upstream suite or Rails cold measurement
is run. Final-head commands, identities and numerical results belong in the
English PR description. Read automated inline comments after opening the PR
and after every push, and resolve Major/P1/P2 findings before requesting merge.
