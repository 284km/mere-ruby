# Parser follow-up 6: Array element source lines

Branch codex-misc-array-element-locations starts from main 323706a7,
including #239. Corpus 992 stays in the parser/lexer range.

The evaluator now annotates call-capable binary and unary Array elements,
which includes interpolation and !call. These use the actual element's
source position. Existing method/index/bare-call annotations remain.

A naive extra tok_line call per operator element was rejected during
validation: a 10,000-element computed Array grew from about .011 s to
.335 s. The final parser shares its logical-line lookup across consecutive
elements and invalidates the cache when parsing observes another line.
Continued lines retain the existing exact physical-position path. Only
integer line/epoch counters are retained globally; token tails are not.
Literals still avoid a position lookup entirely.

Corpus 992 checks all seven element shapes in eval and actual child files,
a preceding multiline String, nested/multiline expressions, continuations,
and a 100,000-element computed Array. Both engines match Ruby. The actual
file cases preserve the VM's already-correct line behavior.

## Large literal measurements

bench/large_literal_parse.rb runs with --seed=1 and tight GC, interleaving
main and candidate three times each. Values below are medians of elapsed
seconds and maxima of RSS bytes. The busy host makes elapsed times noisy;
instruction counts are included separately.

| Shape / engine | Main seconds | Candidate seconds | Main RSS bytes | Candidate RSS bytes |
| --- | ---: | ---: | ---: | ---: |
| 100,000 Array / eval | 0.127494 | 0.094204 | 140820480 | 140853248 |
| 100,000 Array / vm | 0.070281 | 0.107629 | 141770752 | 141623296 |
| 50,000 Hash keys / eval | 0.119911 | 0.244550 | 182632448 | 184565760 |
| 50,000 Hash keys / vm | 0.129745 | 0.104955 | 201310208 | 201408512 |
| 100,000 operator Array / eval | 0.271213 | 0.258742 | 222937088 | 237240320 |
| 100,000 operator Array / vm | 0.283328 | 0.490507 | 223789056 | 238075904 |

Median instructions for the bare 100,000-element Array are 1.615 G main
versus 1.617 G candidate on evaluator, and 1.611 G versus 1.615 G on VM.
For 50,000 Hash keys they are 3.624 G versus 3.634 G, and 4.198 G versus
4.203 G. The computed 100,000-element Array takes 2.365 G / 2.373 G
candidate instructions, versus 2.262 G / 2.260 G on main; it remains a
linear parse instead of rescanning the rest of the line for each element.

The unchanged test_allocation.rb Literal selections run separately with
their original 100,000-element Array and 100,000-key Hash sizes and original
budgets. Both pass 2 tests / 8 assertions on both builds and engines:

| Engine / case | Main seconds | Candidate seconds | Main file RSS bytes | Candidate file RSS bytes |
| --- | ---: | ---: | ---: | ---: |
| Evaluator / Array | 0.59 | 0.66 | 316473344 | 316522496 |
| Evaluator / Hash | 1.07 | 1.21 | 316473344 | 316522496 |
| VM / Array | 0.59 | 0.56 | 328024064 | 342196224 |
| VM / Hash | 1.35 | 1.61 | 328024064 | 342196224 |

## Related unchanged upstream backtrace file

| File | Candidate result | Main evaluator RSS | Candidate evaluator RSS | Main VM RSS | Candidate VM RSS |
| --- | --- | ---: | ---: | ---: | ---: |
| ruby/test_backtrace.rb | 3 tests, 8 assertions, 0 failures, 0 errors, 0 skips | 172048384 | 172441600 | 173916160 | 174653440 |

## Validation policy

The reference is the clean pinned Ruby 4.0.10. The unchanged upstream
files above run one file at a time, against main and both candidate engines,
with `--seed=1` and `MERE_RUBY_GC_TIGHT=1`. RSS is max resident bytes from
`/usr/bin/time -l`. No gems are installed into the reference.

The O2 binary uses compiler 9dec2ff6 and mgz 661a01d8. Full acceptance is
running sequentially: `sh run_corpus.sh --both`, followed by
`MERE_RUBY_VM=1 sh run_corpus.sh --both`. Each includes gc_roots,
dup_defs, dead_defs, meth_writes, name_spec, rx_caps, ns_names, name_len
and full record_hygiene. Generated C is checked with
`MR_C=mr.c sh tools/bracket_depth_check.sh`; this loop record is also
checked explicitly with record_hygiene. Focused passing cases are not a
substitute for those pending sweeps. No full unit suite or Rails component
suite was run; no workflow is changed.
