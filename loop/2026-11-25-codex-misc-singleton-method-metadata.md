# Collect metadata belonging to unreachable object singleton classes

B7. Branch base: main `50644298`. Reference: clean Ruby 4.0.10,
revision `a704b7cd95`; Mere `9dec2ff6`, mgz `661a01d8`, O2. No reference
gems were installed.

The GC owner parser now associates object-singleton metadata with its receiver
rather than treating closure environments as permanent roots. Existing owner
graph marking and sweeping therefore retain metadata only while its object or
singleton class is reachable. Corpus 1106 matches Ruby on both engines with
tight GC: bulk transient receivers are reclaimed, retained Methods and
singleton Classes preserve their receivers and closure payloads, and cyclic
Proc bodies are reclaimed. The WeakMap bound allows conservative native stack
roots while rejecting retention of all 1000 receivers.

## Related upstream comparisons

Each unchanged Ruby 4.0.10 file runs separately through unittest/try.sh,
with `--seed=1` and `MERE_RUBY_GC_TIGHT=1`. Max RSS below is in bytes from
`/usr/bin/time -l`, with binaries beside their C API headers.

| File | Main result | Candidate result | Main evaluator RSS | Candidate evaluator RSS | Main VM RSS | Candidate VM RSS |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| ruby/test_method.rb | 5 tests, 10 assertions, 0 failures, 0 errors, 0 skips | 5 tests, 10 assertions, 0 failures, 0 errors, 0 skips | 168476672 | 169050112 | 185876480 | 185679872 |
| ruby/test_weakmap.rb | 3 tests, 7 assertions, 0 failures, 0 errors, 0 skips | 3 tests, 7 assertions, 0 failures, 0 errors, 0 skips | 163708928 | 164331520 | 165642240 | 163184640 |

## Transient singleton method RSS

`bench/singleton_method_retention.rb 30000 KIND --seed=1` runs with
`MERE_RUBY_GC_TIGHT=1` and measures max RSS on unchanged O2 binaries.
Literal block definitions and a reused Proc body are measured separately.
A 100000-iteration main run was stopped before completion; its partial
measurement is not used in this comparison.

| Kind | Main evaluator | Candidate evaluator | Main VM | Candidate VM |
| --- | ---: | ---: | ---: | ---: |
| block | 192544768 | 119144448 | 179208192 | 109363200 |
| proc | 132071424 | 122028032 | 130744320 | 108052480 |

Plain-object controls at 100000 iterations measured main evaluator/VM
98451456/97943552 bytes and candidate 98418688/97878016 bytes. The reported
3.5x ratio is workload-dependent; this record reports the observed growth
and reduction, without claiming to reproduce that exact ratio.

## Completed acceptance

sh run_corpus.sh --both: 884/884 pass, hash indexing ON and OFF.
MERE_RUBY_VM=1 sh run_corpus.sh --both: 884/884 pass, indexing ON/OFF.
Both complete commands pass all source gates and full record_hygiene.
The generated-C bracket gate passes, 155 required / 1024 supplied.
No full unit suite or Rails component suite was run; no workflow changed.

## Review correction: production helpers in the packed-mark gate

The human review reproduced a real PR-specific CI failure: the owner-parser
slice calls sng_key_id without including its definition. Running the same
gate locally reproduced unbound variable: sng_key_id before the correction.
The checker now extracts the production sng_key_id and its is_digit helper
from the source files and includes them before the owner parser. Four new
checks cover an object-singleton method, a bare object singleton, a nested
singleton and an object-singleton constant owner. The real compiler runs
both ordinary O2 and ASan/UBSan probes successfully.

This follow-up changes only the Python gate and this completed note. All
runtime Mere files, corpus programs and the measured ordinary O2 binary
are unchanged from 215d866e; the completed corpus, upstream and RSS results
above therefore apply without claiming a fresh runtime compilation.
The gate correction, its regression expectations and this note are pushed
together. Source gates and record hygiene are repeated before pushing.

The optional anonymous-parent mark suggestion remains a follow-up. The
review could not expose it in Ruby behavior and classified it nonblocking;
other roots currently preserve those parents on both main and the PR.
This gate-only correction does not change the collector's mark policy.
