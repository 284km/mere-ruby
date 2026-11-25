# Definition-site yield in define_method bodies

B6. Branch base: main `50644298`. Reference: clean Ruby 4.0.10,
revision `a704b7cd95`; Mere `9dec2ff6`, mgz `661a01d8`, O2. No reference
gems were installed.

Corpus 1105 matches Ruby on both engines, covering caller blocks and &block
parameters, lexical yield through nested iterators, optional defaults,
aliases, Proc arguments and singleton methods, defined?(yield), active and
orphan break, and lambda break. All registration paths, including the
class-body statement path, record the definition-site yield block and its real
home/lambda metadata. Parameter binding continues to receive the caller block.

## Related upstream comparisons

Each unchanged Ruby 4.0.10 file runs separately through unittest/try.sh,
with `--seed=1` and `MERE_RUBY_GC_TIGHT=1`. Max RSS below is in bytes from
`/usr/bin/time -l`, with binaries beside their C API headers.

| File | Main result | Candidate result | Main evaluator RSS | Candidate evaluator RSS | Main VM RSS | Candidate VM RSS |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| ruby/test_method.rb | 15 tests, 45 assertions, 0 failures, 0 errors, 0 skips | 15 tests, 45 assertions, 0 failures, 0 errors, 0 skips | 166838272 | 168083456 | 186351616 | 186482688 |
| ruby/test_defined.rb | 1 tests, 2 assertions, 0 failures, 0 errors, 0 skips | 1 tests, 2 assertions, 0 failures, 0 errors, 0 skips | 164347904 | 163545088 | 165117952 | 163889152 |
| ruby/test_proc.rb | 4 tests, 11 assertions, 0 failures, 0 errors, 0 skips | 4 tests, 11 assertions, 0 failures, 0 errors, 0 skips | 173096960 | 173129728 | 206520320 | 204914688 |

## Completed R6 acceptance

sh run_corpus.sh --both and MERE_RUBY_VM=1 sh run_corpus.sh --both each
pass 884/884 programs with hash indexing ON and OFF. Both commands pass
all source gates and full record_hygiene. The generated-C bracket gate
passes, 155 required / 1024 supplied. These are the completed R6 results
previously posted in the PR description, not pending work.
No full unit suite or Rails component suite was run; no workflow changed.

## Review correction: forwarded body Procs

The initial change captured the registration helper's block for a Proc
forwarded with &body. That overrides the Proc's actual lexical yield
context. Both define_method and define_singleton_method are affected.

The block-pass definition paths now recognize the supplied Proc and derive
the enclosing yield block and home/lambda metadata from its defining
environment and existing yield markers, as the positional-Proc paths do.
Direct literal blocks retain their registration-site context. No new
global source slot or permanent root is introduced.

Corpus 1105 adds both registration forms through an unrelated helper,
with the original definition block and a different caller block. All four
calls now print :definition on clean Ruby and both candidate modes.
The complete 1105 witness matches on both engines with tight GC.

The unchanged upstream selections were repeated with seed 1 and tight GC;
all reference, main and candidate runs pass. Max RSS is bytes:

| File | Result | Main evaluator RSS | Candidate evaluator RSS | Main VM RSS | Candidate VM RSS |
| --- | --- | ---: | ---: | ---: | ---: |
| ruby/test_method.rb | 15 tests, 45 assertions, 0 failures, 0 errors, 0 skips | 167886848 | 169639936 | 185827328 | 184500224 |
| ruby/test_defined.rb | 1 tests, 2 assertions, 0 failures, 0 errors, 0 skips | 164364288 | 165543936 | 164626432 | 163430400 |
| ruby/test_proc.rb | 4 tests, 11 assertions, 0 failures, 0 errors, 0 skips | 174473216 | 173146112 | 203227136 | 203423744 |

The corrected R6 O2 binary completed both full 884/884 corpus sweeps.


## Review correction: implicit super uses the lexical block

The human review found a regression: super() and super(*args) without an
explicit block forwarded the method caller block after the frame swap was
removed. Clean Ruby passes the body Proc's lexical block. The exact expanded
1105 witness reproduces that difference on both R6 engines.

The evaluator's implicit-super branch and the VM's direct super path now
select the lexical block in a define_method frame. Explicit block-pass,
&nil and literal blocks retain their own paths. The existing body_yields
scan already counts implicit super: the evaluator uses yscan_defined and
the VM metadata explicitly includes super. The capture scan and its set of
retained bodies are unchanged by this correction.

Corpus 1105 adds implicit super with and without a caller/definition block,
rest arguments, caller &block parameters, explicit &block, &nil, literal
blocks, nested iterators and forwarded body Procs. All 28 lines match clean
Ruby on evaluator and VM with tight GC. Corpus 124, 967 and 970 also match
stdout, stderr and status on both engines.

The final ordinary O2 R7 binary SHA-256 is
e689d5ee217bf7977bd938d2021e98e74152b70a786e4b0d06c82ae73dce2d2a,
with unchanged compiler 9dec2ff6 and mgz 661a01d8 pins.
The generated-C bracket gate passes, 155 required / 1024 supplied.
Fresh R7 sh run_corpus.sh --both: 884/884 pass, hash indexing ON and OFF.
MERE_RUBY_VM=1 sh run_corpus.sh --both: 884/884 pass, indexing ON/OFF.
Both fresh complete commands pass all source gates and full record_hygiene.
No corpus program is excluded. Explicit hygiene for this completed loop
note passes before the single code/regression/benchmark/record push.

The nonblocking review suggestions remain recorded follow-ups: ordinary
yield's existing frame lookup cost; additional capture memory on yield
bodies; reflective block_given? and class_eval/String/binding.eval gaps.
This correction adds no capture scan and does not claim to fix those gaps.


### R7 related upstream and memory comparisons

Unchanged upstream selections run one file at a time, --seed=1 and tight
GC, against clean reference, main a9e68981 and final R7. All five runs per
file pass, including the additional super/block selections:

| File | Tests / assertions | Main evaluator RSS | R7 evaluator RSS | Main VM RSS | R7 VM RSS |
| --- | --- | ---: | ---: | ---: | ---: |
| ruby/test_super.rb | 4 / 10 | 167002112 | 164020224 | 166887424 | 164954112 |
| ruby/test_method.rb | 15 / 45 | 171786240 | 167559168 | 187236352 | 187121664 |
| ruby/test_defined.rb | 1 / 2 | 167788544 | 164970496 | 167215104 | 165003264 |
| ruby/test_proc.rb | 4 / 11 | 172425216 | 173932544 | 205062144 | 203882496 |

bench/define_method_lexical_super.rb separately measures 6000 classes,
each with one captured-yield, implicit-super or plain body plus one plain
body; ordinary-yield and define_method-super loops run 400000 calls.
Three alternating ordinary O2 main-a9/R6/R7 runs per engine use tight GC
and --seed=1. All 90 outputs match Ruby. These are new deterministic
workloads, not a claim to reproduce the reviewer's exact benchmark totals.
Max RSS bytes across three runs:

| Case | Engine | Main a9 | R6 | R7 |
| --- | --- | ---: | ---: | ---: |
| capture | eval | 178569216 | 173424640 | 173473792 |
| capture | vm | 159596544 | 158728192 | 158793728 |
| super | eval | 178651136 | 165904384 | 166182912 |
| super | vm | 158728192 | 158711808 | 158842880 |
| plain | eval | 133054464 | 132251648 | 132399104 |
| plain | vm | 129400832 | 128450560 | 126550016 |
| yield_loop | eval | 83820544 | 83247104 | 83394560 |
| yield_loop | vm | 88915968 | 88211456 | 88342528 |
| super_loop | eval | 94699520 | 98287616 | 94076928 |
| super_loop | vm | 91455488 | 94453760 | 90570752 |

Median instructions retired in the same runs, with identical checksumming:

| Case | Engine | Main a9 | R6 | R7 |
| --- | --- | ---: | ---: | ---: |
| capture | eval | 3365181446 | 3405127246 | 3405360184 |
| capture | vm | 3066575314 | 3098169510 | 3093981482 |
| super | eval | 3381558795 | 3078449921 | 3080146723 |
| super | vm | 3108982611 | 3144507471 | 3147380666 |
| plain | eval | 2332354405 | 2335530442 | 2334415418 |
| plain | vm | 2647343844 | 2651857099 | 2649902723 |
| yield_loop | eval | 13960861624 | 14067432839 | 14070688940 |
| yield_loop | vm | 16241841675 | 16475207114 | 16464083442 |
| super_loop | eval | 32854821737 | 29091434496 | 32465608223 |
| super_loop | vm | 35831661609 | 31536971532 | 35541258075 |

Retained definition memory is unchanged from R6 within 0.3 MB in captured
and implicit-super cases; the capture scan has not grown. Ordinary-yield
instructions are +0.02% evaluator / -0.07% VM versus R6. Correct implicit
super now actually calls the definition block; the incorrect R6 path did
not call it. That loop is +11.6% / +12.7% versus the incorrect R6 path,
but -1.18% / -0.81% versus main a9. No ordinary-yield frame lookup
optimization or broad memory reduction is claimed by this correction.
