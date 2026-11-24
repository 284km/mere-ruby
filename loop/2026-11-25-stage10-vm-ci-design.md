# Design memo: what CI checks of the ISeq VM, and four checks it lacks

A memo, with no change to the code or to CI. It is for the decision on making the VM the default execution (note 558, item 1): which checks should be in CI before that, what each costs, and what each would have caught. Each proposal below changes `.github/workflows/ci.yml`, so each is a PR of its own for the owner to read.

## What CI checks today

The corpus job (macOS) and the Linux job both run `tools/iseq/vm_corpus.sh`: every corpus program under MERE_RUBY_VM=1, its output and exit status compared with ruby's. A program that differs fails the job.

That is the whole of it. A program the VM declines runs on the evaluator, matches ruby, and is counted as a fallback and passed.

## What that leaves open

**1. A program that stops running on the VM.** A change that makes the native compiler or the loader decline something it took yesterday turns programs into fallbacks, and the job stays green. The number is printed and nobody is asked to read it. The same is so of a required file: `vm_corpus.sh` asks only of the main script.

**2. The VM forced.** `tools/iseq/vm_check.sh` runs 245 snippets through `RubyVM::InstructionSequence#eval` with the VM forced, and compares each byte with ruby. Forced means a refusal is a failure, so it is the one check where "the VM does not take this" is red. It is not in CI.

**3. The two compilers against each other.** `tools/iseq/native/check.sh` compiles a file with the native compiler and with the Ruby one, and compares the two trees as text. The native compiler is the one that runs; the Ruby one is the one whose output was compared with ruby's own `#to_a` (`tools/iseq/compare_with_ruby.rb`, `compare_files.rb`). Neither comparison is in CI. A change to `ic/` is checked in CI only by what the corpus happens to run.

**4. CRuby's own tests on the VM.** The unit-test shards run on the evaluator. Nothing in CI runs a test file under MERE_RUBY_VM.

## The four checks

Times are this machine's, each command run alone on main with #231, and CI's runners are slower.

### 1. A budget of fallbacks

`vm_corpus.sh` fails when a program falls back that is not on a list kept in the repository.

- The list is a file, `tools/iseq/vm_fallbacks.txt`: one corpus program a line, with the reason as `vm_corpus.sh` prints it. Today it would have one line: corpus 370, a `shareable_constant_value` write of a value that is not a literal (round 62, #231, took it from four to one).
- A program that falls back and is not listed fails the job, with its reason. A listed program that now runs on the VM fails it too, with "remove it from the list", so the list cannot go stale.
- Adding a line is a reviewed change, which is the point: a fallback becomes something a PR says, not something a number hides.
- Cost: none. The verdicts are already computed.

A second part, for required files: `MERE_RUBY_VM=report` names each file the VM declined. One more run of the corpus under `=report`, with the lines collected and held to a second list, would cover what a program requires. Cost: one more VM corpus run, 2 min 20 s here at four jobs. This part could wait: round 60's sweep (every corpus program run as a required file) found no required-file difference, and the main script's verdict covers most of the compiler.

### 2. vm_check in the corpus job

One step: `sh tools/iseq/vm_check.sh`. 1 min 21 s. It needs nothing the job does not have.

### 3. The compilers' comparison

Two parts, and they differ in what they need.

- `tools/iseq/native/check.sh` over a fixed list of files (the corpus, or a sample of it, and `lib/`): it builds a small tool from `ic/` with the Mere compiler and runs the Ruby compiler on mere-ruby. 41 s for the whole corpus, 873 files: 871 the same, 0 different, 1 the native compiler declines and the Ruby one compiles, 1 neither compiles. The job already has the Mere compiler.
- `compare_with_ruby.rb` and `compare_files.rb` compare the Ruby compiler's tree with ruby's own. They run under the reference ruby, which the job has: 5 s for the whole corpus (872 the same, 1 refused), and under 1 s for the 460 snippets.

Together they close the chain: ruby's `#to_a` = the Ruby compiler's = the native compiler's, for the files listed.

Both are cheap enough to run over the whole corpus, which is the simplest rule: no list to keep. The verdict to fail on is "different" (and "failed"); a file one of them refuses is the fallback list's business, and the native comparison's "declined by the native compiler, compiled by the Ruby one" is a second kind of fallback worth a line there: the file still runs on the VM, at many times the cost to compile.

### 4. Unit tests on the VM

The largest, and the one that decides whether the default can change.

- **What exists**: by hand, test/ruby's 142 files were run on both executions on 2026-11-17 (note 552, section 15): VM 9,532 passing tests, evaluator 9,545, the difference a leak check and a time limit. Since then the comparison has been made for the files a round touched (seven to fourteen a round). No test failed on the VM alone until round 62 (#231), where one did: a test whose file had been falling back whole.
- **A first step that costs little**: one shard, on a schedule and not on every push, that runs a fixed list of test/ruby files under MERE_RUBY_VM=1 and compares each test's outcome with the evaluator's in the same build. The comparison is between the two executions, not with ruby, so it needs no baseline: a test that passes on one and not on the other is the finding. The time is not measured yet: the eight files a round usually compares (test_regexp, test_parse, test_syntax, test_eval, test_require, test_rubyoptions, test_iseq, test_exception) take about five minutes on one execution here, and all of test/ruby is to be measured when the comparison is next run in full.
- **The full form**: the unit-test shards run twice, once with MERE_RUBY_VM=1. That doubles the largest part of CI (the shards have a 330-minute limit). It is what "the VM is the default" would mean in CI anyway: when the default changes, the shards run on the VM and the evaluator becomes the second run, or is dropped.

So the order proposed is: the scheduled shard now, to find what is VM-only while the evaluator is still the default; the full double run only for the PR that changes the default, to show the numbers side by side once.

## Order, and what each would have caught

| | cost in CI | would have caught |
|---|---|---|
| 1. fallback list | none | a compiler refusal introduced by a change; and it names what is not checked: test_hash.rb fell back whole for one instruction, and the VM's wrong answer in it (a literal Hash's key was not the fstring, #231) went unseen until the refusal was removed |
| 2. vm_check | 1 min 21 s | a refusal or a wrong answer in the forced VM (rounds 34 to 41 were built against it by hand) |
| 3. compilers' comparison | under 1 min | a divergence of the native compiler from the Ruby one (50 files' worth were found by hand when `ic/` was written) |
| 4. scheduled VM unit shard | not measured, on a schedule | a test that fails on the VM alone |

1, 2 and 3 are small and independent, and could be one PR or three. 4 needs a script in `unittest/` that compares each test's outcome on the two executions; so far that comparison has been made by hand.

## Recorded here, found while writing this

Under MERE_RUBY_VM a regexp literal with a warning was warned of twice, and a required file's regexp literal that did not compile ran anyway. Both were found by reading output by hand in rounds 60 and after (#223, #229), and neither by a check: the corpus compares stdout and the exit status, not stderr. A check of what a program writes to stderr, on both executions, is a fifth gap, and a wider one than the VM's.
