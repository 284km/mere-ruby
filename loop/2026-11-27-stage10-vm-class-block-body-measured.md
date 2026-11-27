# What a class body run as a block costs on the VM (measured, not changed)

The leak loop (`test_complemented_method_entry_memory_leak`'s body) ran 35% more instructions on the VM than on the evaluator. Most of that was the evaluator's own shortcut for that test's shape. `discard_native_reflection` keeps a discarded `local.method(:sym).unbind` from making its two objects. The VM does not copy it, because it matches only that one statement.

What was left is `Class.new { ... }`'s body. On the VM it is a block of the compiled program, `[SLineQ; SFile; SVm]`, and the class-body walker hands the `SVm` to `register_class_statement`. That sets the body's visibility scope and runs it through `vm_enter`.

## Numbers

Instructions per iteration, 20,000 iterations, evaluator against VM:

| program | evaluator | VM |
|---|---|---|
| `Class.new` | 72.9k | 73.5k |
| `Class.new {}` | 78.4k | 87.7k |
| `Class.new { 1 }` | 81.5k | 87.8k |
| `Class.new { def foo; end }` | 73.4k | 88.1k |
| `Class.new { def foo; end; def bar; end }` | 102.2k | 126.5k |
| `m = Module.new` once, then `Class.new { include m }` | 98.7k | 108.0k |

The VM's own part is a fixed cost of running a block body, about 9k an iteration. The statements in it cost about the same as on the evaluator. A sample of the VM spread that cost over `vm_enter`, the frame pool, `register_class_statement`'s scope slots and running the body's ISeq. No one place held most of it.

## Why it is left as it is

The leak loop is about 200k instructions an iteration, so all of this is about 5% of it. Taking it away means changing how the VM calls a block, for every block, not this one shape. The tables the evaluator keeps for a few shapes of this test (`vm_metadata_shape`) are not widened either: they are shortcuts for a test's shape.
