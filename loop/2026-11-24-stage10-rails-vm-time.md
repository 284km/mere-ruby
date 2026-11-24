# The Rails application on both executions: what it takes, and a class's own attr_reader

Note 558's second item for the VM stream: the real Rails application of `railstest/` (8.1.4.1, six stages, cold) on the evaluator and on the VM, next to ruby 4.0.9.

## The measurement

`railstest/measure.py` drops every inherited `MERE_RUBY_` name from the environment, so the VM could not be asked for. It has a new option:

- `--mere-env MERE_RUBY_NAME=VALUE` (repeatable) sets a variable on mere-ruby's side only.
- The result records the settings as `mere_env`.
- A name that does not start with `MERE_RUBY_`, or an empty value, is refused.

`railstest/check.py` passes (7 controls). The six stages, their bounds (600 s and 2 GiB a stage) and what a PASS requires are unchanged.

**The evaluator**, main cfcc861a's source built with Mere 9dec2ff6, 2026-11-24 15:02 to 15:08. The load average was 6 to 7; another session ran one corpus sweep at the time. All six stages PASS on both sides.

| stage | ruby 4.0.9 | mere-ruby, evaluator | times ruby |
|---|---|---|---|
| Bundler | 0.6 s, 33 MB | 4.1 s, 343 MB | 6.5 |
| the 68 dependencies (native ones built) | 134.9 s, 1,684 MB | 209.1 s, 1,382 MB | 1.5 |
| migration | 5.1 s, 105 MB | 10.8 s, 773 MB | 2.1 |
| boot (the direct `bin/rails`) | 1.5 s, 98 MB | 6.4 s, 771 MB | 4.2 |
| the six tests (31 assertions) | 1.8 s, 114 MB | 10.9 s, 861 MB | 6.2 |
| Puma's HTTP | 2.2 s, 107 MB | 8.9 s, 989 MB | 4.0 |

Against the last recorded cold run (d434c81e, load about 12): boot 7.4 s → 6.4 s, tests 11.8 s → 10.9 s, HTTP 11.0 s → 8.9 s, the dependencies 232.1 s → 209.1 s. The two runs' loads differ, so this is no measure of a change.

**The VM** (`--mere-env MERE_RUBY_VM=1`) does not pass yet. Bundler and the dependencies PASS; migration FAILS, so boot, tests and HTTP are NOT_RUN. Two defects, in the order they were met:

1. thor's own `attr_reader`. This is the section below, fixed here.
2. `Nokogiri::HTML is not a module`: `HTML = HTML4` and then `module HTML`, a module reopened through a constant that names it. #197 has the fix. The VM's cold run is to be taken again once it is on main.

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
- The Rails application, cold, on the evaluator: all six stages PASS on both sides (the table above).
