# A declaration block's def on the ISeq VM

test/ruby whole on both executions (#287) found one test at its time limit on the VM alone: `TestModule#test_complemented_method_entry_memory_leak`, which makes, 300,000 times, a class with one def, a module refining it with one def, and a class using the refinement with one def. The VM took twice the evaluator's time for it, and the difference was the def inside a block.

## Why

The evaluator does not run such a block. `Class.new { def m ... end }`, `Class.new { using X; def m ... end }` and `Module.new { refine X do def m ... end end }` are proved free of anything that could observe the class (no hook, trace, thread or signal; a fresh class; the name not one of the hooks) and their def is written straight into the new class's method table (`native_constructor_declaration`, `native_definition_body`, `native_include_body`). That proof reads the parsed block.

The VM's block has no parsed form: its body is the statement that runs its program (`SVm`). So the proof failed, the block ran, and its `definemethod` went through the class body's walker (`vm_define`, `register_class_v`), a send from the VM through the evaluator's call layers on the way.

## The change

`vm_def_block_body` reads a VM block's program as the parsed form, for the three forms the proof takes:

| the program | the parsed form |
|---|---|
| `definemethod :m; putobject :m; leave` | the def |
| `putself; getglobal/getlocal X; send :using, 1; pop` and the def | `using X` and the def |
| `putself; getglobal/getlocal X; send :refine, 1, block; leave`, the block's program a def | `refine X do` the def `end` |

The def is the one `vm_define` would have made (its name, parameters and body, the line of its `end`, and the tree marked as one a method was defined from). The parsed form goes to the same proof and the same writer, at the two places the evaluator takes it: the `new` call with a literal block (`EMethodB`), and `make_anon_cls_block` for the other ways a block reaches `new`. Any other program, or a proof that fails, runs the block as before. Not while coverage runs.

## Numbers

Instructions, the median of three runs alternating main fd5f54b0 and this branch:

| program | execution | main | here |
|---|---|---|---|
| `Class.new { def foo; end }`, 300,000 times | VM | 19.75 G | 13.01 G (-34%) |
| | evaluator | 9.95 G | 9.97 G |
| the test's loop (class, refinement, using), 100,000 times | VM | 37.90 G | 28.49 G (-25%) |
| | evaluator | 20.24 G | 20.27 G |

The test itself on the VM, three runs alternating, at a load of about 5: main stops at the 10 s limit each time (10.10 s); here it passes each time in 8.1 to 8.2 s. The evaluator takes 5.7 s.

What remains of the VM's difference in the test's loop is the `initialize` the loop calls (a method call on the VM), not the def.

Corpus 825 has each form and what it means: the method's owner, its line, a refinement used from the class's method, through `Method#unbind`, a local as the argument, a superclass, `initialize`'s visibility, a def named as a hook, a block of two defs, and the class's `inherited` hook. It matches ruby on both executions, here and on main.

CHECKED
