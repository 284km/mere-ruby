# CI checks of the ISeq VM: the fallbacks held to a list, the forced VM, the compilers' chain

#232 proposed four checks CI did not make of the VM; the owner decided to take the first three now. This is those three, and a fourth found while writing them.

## 1. A list of fallbacks

`tools/iseq/vm_corpus.sh` already ran in CI, on macOS and Linux, and failed on a program whose output under MERE_RUBY_VM differs from ruby's. A program the VM declined ran on the evaluator, matched, and passed as a "fallback".

It is now held to `tools/iseq/vm_fallbacks.txt`, a list in the repository: one program a line and why. The script fails

- when a program falls back that is not listed: "UNLISTED fallback corpus/NNN_x.rb (why): the VM declines a program it is not listed to decline";
- when a listed program runs on the VM: "LISTED but on the VM: ... remove its line".

Only the programs of the run are held to the list, so a run over a few files works as before. `VM_FALLBACKS=<file>` names another list and `VM_FALLBACKS=none` none.

The list is empty: since round 63 (#233) every corpus program runs on the VM. Adding a line is a change a PR has to make, and say why.

How it was checked, on this branch:

| | the run | exit |
|---|---|---|
| a program with a BEGIN block added (the VM declines it), not listed | "UNLISTED fallback ... (a BEGIN block)" | 1 |
| the same, with a list naming it | passes | 0 |
| a list naming corpus 801, which runs on the VM | "LISTED but on the VM: corpus/801_... runs on the VM now" | 1 |
| `VM_FALLBACKS=none` | passes | 0 |

The files a program requires are not held to a list yet (`MERE_RUBY_VM=report` names those): the owner put that later.

## 2. The forced VM

A step runs `tools/iseq/vm_check.sh`: 245 snippets through `RubyVM::InstructionSequence#eval` with the VM forced, each compared with ruby, stdout and stderr. A snippet the VM declines fails here.

## 3. The compilers' chain

What runs on the VM is the native compiler's sequence. That it is ruby's rests on two comparisons, made by hand until now:

- the Ruby compiler (`lib/iseq_compiler_ext.rb`) against ruby's own `#to_a`: `compare_with_ruby.rb` over the 460 snippets and `compare_files.rb` over the whole corpus;
- the native compiler against the Ruby one: `tools/iseq/native/check.sh` over the whole corpus.

One step runs the three. A file that differs fails it; a file one of them declines is counted and passes, being the list of fallbacks' business when the VM declines it.

`compare_with_ruby.rb` exited 0 whatever it found; it exits 1 when a snippet differs now, and writes its two files in a directory of its own.

## 4. The embedded copy of the Ruby compiler

Writing these, it showed that mere-ruby's copy of the Ruby compiler was stale. mere-ruby carries it as a string in `m_pathname_lib.mere`, made from the lib by `tools/gen_pathname_lib.rb`. Round 63 (#233) changed the lib and not the copy, and the comparisons above, which read the lib, could not see it.

A step generates the file again and compares it, as the job does for the Psych and network libraries. **It fails on main as it was**: the regeneration is in round 65's PR (#257), which this one is built on.

## Times

Here, each step run alone at a load of 25 to 35 (other sessions' work), on main 323706a7 with #257:

| step | here |
|---|---|
| `vm_corpus.sh -j 3` with the list (it ran before; the list costs nothing) | 5 min 39 s |
| `vm_check.sh` | 2 min 1 s |
| `compare_with_ruby.rb` (460 snippets) | 1 s |
| `compare_files.rb` (893 files) | 8 s |
| `native/check.sh` (893 files) | 1 min 2 s |
| `gen_pathname_lib.rb` and `cmp` | 1 s |

CI's own times are added below when this PR's run is through.

## Checked

Against ruby 4.0.10 (tools/ref_ruby.sh), built with Mere 9dec2ff6, on main 323706a7 with #257:
- every step above passes, with the numbers in its table: 893 programs on the VM and none against the list; vm_check 245/245; 460 snippets; 893 files the same in each comparison, none refused; the embedded copy as generated.
- the list check fails and passes as the first table says.
- With the Ruby compiler made wrong on purpose (a `nil` pushed with `putobject` instead of `putnil`), `compare_with_ruby.rb` exits 1 (400 snippets the same, 60 different), and so does `compare_files.rb` over the first nine corpus programs (2 different).
