# The Rails application on both executions: what it takes, and a class's own attr_reader

Note 558's second item for the VM stream: the real Rails application of `railstest/` (8.1.4.1, six stages, cold) on the evaluator and on the VM, next to ruby 4.0.9.

## The measurement

`railstest/measure.py` drops every inherited `MERE_RUBY_` name from the environment, so the VM could not be asked for. It has a new option:

- `--mere-env MERE_RUBY_NAME=VALUE` (repeatable) sets a variable on mere-ruby's side only.
- The result records the settings as `mere_env`.
- A name that does not start with `MERE_RUBY_`, or an empty value, is refused.

`railstest/check.py` passes (7 controls). The six stages, their bounds (600 s and 2 GiB a stage) and what a PASS requires are unchanged.

**Both executions pass all six stages**, cold, against ruby 4.0.9: [`railstest/cold_2c167cfd_evaluator.json`](../railstest/cold_2c167cfd_evaluator.json) and [`railstest/cold_2c167cfd_vm.json`](../railstest/cold_2c167cfd_vm.json). The source is this change's first commit, 2c167cfd, on main 17a5db5f, built with Mere 9dec2ff6. The runs were made one after the other on 2026-11-24, 16:22 to 16:29 and 16:29 to 16:36, at a load average of 7 to 9; another session ran two corpus sweeps at the time.

Seconds and peak RSS of each stage's process family:

| stage | ruby 4.0.9 | mere-ruby, evaluator | mere-ruby, VM |
|---|---|---|---|
| Bundler | 0.9 s, 41 MB | 4.6 s, 387 MB | 6.8 s, 380 MB |
| the 68 dependencies (native ones built) | 147.9 s, 1,601 MB | 232.6 s, 1,141 MB | 231.7 s, 1,271 MB |
| migration | 4.8 s, 107 MB | 10.7 s, 751 MB | 13.8 s, 1,122 MB |
| boot (the direct `bin/rails`) | 1.6 s, 100 MB | 6.6 s, 785 MB | 10.3 s, 1,280 MB |
| the six tests (31 assertions) | 1.8 s, 115 MB | 11.6 s, 844 MB | 14.6 s, 1,273 MB |
| Puma's HTTP | 2.3 s, 106 MB | 9.9 s, 927 MB | 12.6 s, 1,514 MB |

(The reference column is the evaluator run's; the VM run's reference side was within 0.3 s of it at each stage.)

**What the table says.**
- The evaluator takes 4 to 6 times ruby's time to boot, test and serve, and about 8 times its memory.
- **The VM is slower than the evaluator on this application**: 1.3 to 1.6 times its time in the four stages that load Rails, and 1.5 times its memory. Boot is 10.3 s against 6.6 s.
- The benchmark programs of rounds 57 and 58 run code many times. Booting Rails runs most code once: about three thousand files are read, and on the VM each is first compiled to an instruction sequence. That is the cost this table shows, and it is what stands between the VM and being the default. Measuring it by its parts (the compile, the load of the sequence, the run) is the next round.

**How the VM got here.** Its first cold run failed in migration, and so did its second:
1. thor's own `attr_reader`. This is the section below, fixed here.
2. `Nokogiri::HTML is not a module`: `HTML = HTML4` and then `module HTML`, a module reopened through a constant that names it. #197 fixed it.

An earlier pair of runs on main cfcc861a (before #197) had the evaluator passing all six stages, with boot at 6.4 s, tests at 10.9 s and HTTP at 8.9 s at a load average of 6 to 7.

## A class's own attr_reader is called

thor defines, in the module its classes are extended with:

```ruby
def attr_reader(*) = no_commands { super }
```

A Rails command class calls `attr_reader :current_subcommand` inside a `no_commands do … end` block. On the VM that failed with "super: no superclass method 'attr_reader' for class Rails::Command::Base", and every `bin/rails` command with it.

Ruby calls a class's own `attr_reader` (and `attr_writer`, `attr_accessor`, `attr`) however the call is written. Here it depended on the form and the execution:

| the call | ruby | evaluator | VM |
|---|---|---|---|
| a statement of the class body | the override | the builtin | the builtin |
| in a block in the class body | the override | the builtin | the override, whose `super` failed |
| `send(:attr_reader, …)`, `self.attr_reader …` | the override | the builtin | the builtin |

**The fix.**
- The builtin arm for a class receiver steps aside when the class has its own method of that name (`cls_meth_own`: on its singleton class, in a module it was extended with, or in one prepended to the singleton). The call then reaches the program's method, as any class method's does.
- The class body's statement (`SAttr` in register_class) does the same, and calls it (`sattr_call`).
- `super` from the override reaches the builtin once, past the override (`bi_skip`, in `super_missing`).
- What the override's `super` defines is public even under the body's `private`. Ruby's `Module#attr_reader` reads the default visibility of the frame that called it, and that frame is the override's.

Corpus 814 has every form: the class body, a block there, `each`, `send`, `self.`, the four names, `def self.`, `class << self`, an override that calls no `super`, a module prepended to the singleton class, `Module.new` and `Class.new` blocks, a `private` section, and `method_added`'s order inside the override. It matches ruby on both executions and differs on main's build on both.

**Left, on the evaluator only:** a class body's statement `attr :x` calls the program's `attr_reader`, not its `attr`. The parser reads `attr :x` as the reader's statement and does not keep which name was written. The VM calls `attr`.

**Left, on both executions (from the review of #209):** a program that redefines `Module#attr_reader` or `Module#attr` itself replaces the builtin in ruby, and a `super` in it is a NoMethodError. Here that `super` still reaches the builtin.

## A first look at the VM's boot

The measured application, booted again in the gem home the cold run left (`bin/rails runner script/boot.rb`), by instructions: 54.4 G on the evaluator and 85.4 G on the VM, 57% more; peak RSS 642 MB and 896 MB.

A sample of the VM's boot puts the compile of a file to an instruction sequence and its load at about a tenth of the run (`ic_vm_native` 7.5% with `ic_to_val` 3% inside it, `vm_load` 2%). So most of the 57% is not the compile. It is in running code that runs once: a class body's definitions (`vm_define` is under about 14% of the samples) and the calls of a file's top level. The next round takes this apart against a sample of the evaluator's boot.

## Checked

Against ruby 4.0.9 (tools/ref_ruby.sh), built with Mere 9dec2ff6, on main cfcc861a:
- corpus 850/850. Under MERE_RUBY_VM=1: 846 on the VM, 4 fell back, 0 different.
  - The sweep was started from a backgrounded subshell, where corpus 778 (a child that inherits an ignored SIGINT) differs for that reason alone; it was run again by itself and matches on both executions.
- Corpus 814 differs on main's build, on both executions.
- vm_check 245/245.
- The gates: dead defs, dup defs, gc roots, bracket depth.
- The CI corpus job's OpenSSL checks: asn1, provider, formats, reinitialize, memory, wasm.
- `railstest/check.py`: 7 controls pass.
- These give the same counts as main cfcc861a's build, on both executions: test_module, test_class, test_object, test_method, test_super, test_refinement, test_eval and test_alias.
- The Rails application, cold, on main 17a5db5f with this change: all six stages PASS on the evaluator and on the VM (the table above).
- On main 17a5db5f with this change, the tree that was pushed: corpus 854/854; under MERE_RUBY_VM=1, 850 on the VM, 4 fell back, 0 different; vm_check 245/245; the gates.
