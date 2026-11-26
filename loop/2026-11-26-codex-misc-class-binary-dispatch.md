# A2: class/module arithmetic dispatch

Branch starts from main 68fee417. Before editing, the actual-frame probe on
main 8f412f51 reproduces TypeError for Class + Integer on both engines;
clean Ruby 4.0.10 raises NoMethodError. This is the remaining original
error_highlight test_OP_CDECL_toplevel_2 cause.

| Cause | Main | Ruby 4.0.10 |
| --- | --- | --- |
| Class/module arithmetic falls into numeric coercion | Integer cannot be coerced into Class | Send the operator, honoring user methods and method_missing; otherwise NoMethodError with actual call metadata. |

The native arithmetic guard now dispatches Class/Module receivers normally
and preserves Module ancestry comparisons. The RHS evaluates normally
before native fallback. Method-form arithmetic excludes the generic
coercion arm so a missing Class operator cannot recursively redispatch.
The real Prism locations already exist; no location heuristic is added.

## Completed focused acceptance and dispatch cost

Corpus 1125's 38 lines match clean Ruby 4.0.10 on both engines, including
operator/method spelling, user method_missing, inherited and late-installed
overrides, and Module ancestry comparisons. Ordinary O2 candidate SHA-256:
`eefb5bd1388b679d44ce8f9ddebab0932fa1a6910ca72609952613029d2b2439`.

The original error_highlight OP_CDECL_toplevel_1/2 selection passes 2/16
on reference and candidate in both engines. Main 68fee417 gives 2/10 with
one failure. The original Module comparison selection passes 8/47 on all
three runtimes, both engines. The following maximum RSS values use
MERE_RUBY_GC_TIGHT=1 and the unchanged --seed=1 selection, in bytes.

| Original file | Phase | Engine | Max RSS | Outcome |
| --- | --- | --- | ---: | --- |
| `error_highlight/test_error_highlight.rb` | main | evaluator | 310165504 | 2 tests, 10 assertions, 1 failures, 0 errors, 0 skips |
| `error_highlight/test_error_highlight.rb` | main | VM | 338214912 | 2 tests, 10 assertions, 1 failures, 0 errors, 0 skips |
| `error_highlight/test_error_highlight.rb` | candidate | evaluator | 327434240 | 2 tests, 16 assertions, 0 failures, 0 errors, 0 skips |
| `error_highlight/test_error_highlight.rb` | candidate | VM | 387104768 | 2 tests, 16 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_module.rb` | main | evaluator | 175554560 | 8 tests, 47 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_module.rb` | main | VM | 204046336 | 8 tests, 47 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_module.rb` | candidate | evaluator | 178241536 | 8 tests, 47 assertions, 0 failures, 0 errors, 0 skips |
| `ruby/test_module.rb` | candidate | VM | 206618624 | 8 tests, 47 assertions, 0 failures, 0 errors, 0 skips |

Three alternating main/candidate pairs per workload and engine run the same
ordinary binaries with tight GC and fixed --seed=1. Median instructions
retired are the stable cost measure; elapsed seconds and maximum RSS are
recorded alongside them. Compiler 9dec2ff6; mgz 661a01d8.

| Workload | Engine | Main median instructions | Candidate median instructions | Delta | Main median sec | Candidate median sec | Main max RSS | Candidate max RSS |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| integer | evaluator | 8909107885 | 8904552753 | -0.051% | 0.691 | 0.672 | 107298816 | 107266048 |
| integer | VM | 4996281535 | 4994656885 | -0.033% | 0.356 | 0.354 | 112279552 | 112230400 |
| float | evaluator | 11055404172 | 11066095263 | +0.097% | 0.771 | 0.792 | 107233280 | 107282432 |
| float | VM | 5949719246 | 5949439233 | -0.005% | 0.379 | 0.378 | 112459776 | 112443392 |
| string | evaluator | 5119270888 | 5119718159 | +0.009% | 0.400 | 0.397 | 93028352 | 92618752 |
| string | VM | 4277191290 | 4282706923 | +0.129% | 0.315 | 0.308 | 93519872 | 93372416 |
| array | evaluator | 5191095720 | 5192615940 | +0.029% | 0.390 | 0.394 | 107216896 | 107249664 |
| array | VM | 3765533438 | 3772948250 | +0.197% | 0.259 | 0.263 | 103940096 | 103890944 |
| encoding | evaluator | 2590915019 | 2583397802 | -0.290% | 0.212 | 0.194 | 81756160 | 81690624 |
| encoding | VM | 2329407590 | 2330347841 | +0.040% | 0.182 | 0.188 | 82575360 | 82526208 |

## Completed acceptance

- sh run_corpus.sh --both: 964/964 PASS, hash index ON/OFF, exit 0.
- MERE_RUBY_VM=1 sh run_corpus.sh --both: 964/964 PASS, ON/OFF, exit 0.
- Both full proofs use the final eefb5bd1388b O2 binary above.
- Eight source gates PASS: gc_roots, dup_defs, dead_defs, meth_writes,
  name_spec, rx_caps, ns_names and name_len; generated-C bracket depth PASS.
- Full and explicit completed-record record_hygiene and whitespace PASS.

The ErrorHighlight candidate reaches six additional assertions. Its file
maxima describe that complete path; dispatch benchmarks compare identical
workloads. No full unit/Rails suite, reference gem installation or workflow
change. Implementation, regression, benchmark and completed record are
submitted in one push after local acceptance.
