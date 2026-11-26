# A protected region on the VM without a handler of its own

The VM's speed, from the benchmarks furthest from the evaluator (note 558): app_raise and so_exception, 1.07 and 1.08 of the evaluator's instructions.

## Where

A raise caught on the VM passed through more fail handlers than on the evaluator, and each one catches the failure and raises it again: Mere's `fail` formats its message (`snprintf`) and jumps (`longjmp`) each time. On the VM, a raise in a `begin ... rescue` went through:

- `vm_seg`'s handler around the region's body,
- `run_begin_f`'s, which takes it to the rescue clauses,
- and, for each method frame it leaves, `vm_exec`'s, which gives the frame's stack back to the pool.

`vm_seg`'s handler is there for one signal only: the jump `vm_jump` throws, a return, a break, a next or a redo thrown inside a region of the frame or out of one of its rescue or ensure sequences. Anything else it raises again.

Taken apart, with 100,000 raises (instructions, the evaluator against the VM): no frame, 4.21 against 4.63 G; three frames, each with a rescue that does not match, 13.93 against 16.56 G.

## The change

A program can throw that jump only when it, or one of its rescue or ensure sequences, has a throw of a return, a break, a next or a redo (1, 2, 3, 5), or a tail call (how 7), or has a sequence of its own that can. A re-raise (0) and a retry (4) travel as other signals.

`vm_may_jump` says so, once for each generation of a program's id (`vm_jump_memo`; `vm_free` moves the generation on). When it cannot, `vm_seg` is `vm_loop` alone.

## Numbers

Instructions on the VM, the median of three runs alternating main and this branch:

| program | main | here | the evaluator |
|---|---|---|---|
| 100,000 raises, no frame | 4.63 G | 4.48 G | 4.21 G |
| the same, three frames, each with a rescue that does not match | 16.56 G | 15.91 G | 13.93 G |
| app_raise | 10.92 G | 10.53 G | 10.17 G |
| so_exception | 48.49 G | 47.69 G | 45.02 G |
| so_nbody (no rescue: the check costs nothing) | 518.6 G | 518.8 G | |

What is left of the difference is mostly `vm_exec`'s handler, one for each method frame a raise leaves (about 3,200 instructions a frame more than the evaluator). It gives the frame's stack back to the pool; giving it back by depth instead would have to know about Fibers and Threads, which run on stacks of their own. Not this round's.

## Witnesses

Corpus 829: a return from a region's body, from a rescue clause and from an ensure; rescues that match and that do not, nested; a retry; a raise again; a next from a block's region's body and from its rescue, with the ensure run;
a break from a rescue; a next and a break around a region in a `while`; a redo; a return from a lambda's rescue and from a block's rescue in a method; and a hundred raises caught in a block.

CHECKED
