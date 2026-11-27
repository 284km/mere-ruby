# An instance variable's inline cache on the VM

Note 559, step 2c (after 2b, #322: an object's variables in a shape's slots in one slab).

## What a read and a write did

`getinstancevariable` went through `vm_ivar_get`, then `ivs_get_or`, then the door `iv_get_or`:

- `self` from the frame;
- the name without its `@` (a `substring`);
- the name's number (`iv_nid_find`, a hash of the name);
- the object's record (`iv_rec`, a hash of its id);
- the name's slot in the shape (`sh_find`, another hash);
- the slot (`iv_slot_read`).

`setinstancevariable` went through `assign_one`, with its frozen check, to the door `iv_set`, which asks the same three tables and, for a new name, the shape's child (`sh_child`).

## The cache

A shape's number and a name's slot in it never change: shapes are never given back. So each ivar instruction keeps what it found last time in its operand b, which neither of them uses otherwise:

- **A read:** `1 + shape * 4096 + slot`. An object of that shape reads that slot, through `iv_slot_read` (a removed variable reads nil, as at the door).
- **A write:** `1 + (shape before * 4096 + slot) * 2^24 + shape after`.
  - The same shape: the slot is written, unless it holds the removed mark; that is the door's (`iv_readd`, where the name goes last).
  - The child that adds this name: the slot is written and the object's record moves to the child, when its area holds the child's slots. This is `iv_grow`'s first branch, `iv_slots_add` included. A bigger area is the door's.
- **What the cache does not cover** goes through the doors as before and fills the cache:
  - a class variable, a TracePoint, a Ractor;
  - an object in the table (`MERE_RUBY_SHAPES=0`, too complex);
  - `self` that is no object, a frozen object.

## What holds the cache to the door's answer

- **The encoding's bounds.** A read is cached only for a shape below 2^24. Its slot is below 4096: `sh_child` makes no shape past 4,096 names. A write is cached only when both shapes are below 2^24, so the value stays under 2^60. With `MERE_RUBY_SHAPES_MAX` past 2^24, a shape above it is not cached and reads through the door.
- **The ISeq does not show it.** `RubyVM::InstructionSequence#disasm` and `#to_a` are made from the compiler's unit, and the cache is written into the VM's own vector of the instructions. After a run they read as ruby's (`<is:0>`, `[:getinstancevariable, :@a, 0]`).
- **A shape is not a class's.** 2b's tree is one for every object, so two classes that set the same names in the same order share a shape. A shape alone decides a name's slot.
  What is a class's -- its variations (`sh_cls_var`) and its area's size (`sh_cls_cap`) -- the door counts only when it makes a new shape (`sh_child` answers an existing child from `sh_next` first) and when an area grows (`iv_grow`'s second branch).
  The cache does neither: it takes only an existing child, into an area that holds it. An object of class A taking a transition class B made counts nothing at the door either.

## Numbers

Instructions on the VM, the median of three runs alternating main (8e757236) and this branch, both built with Mere 9dec2ff6 (CI's). The evaluator's do not move: the cache is the VM's.

| program | main | here | |
|---|---|---|---|
| `s += @x`, 300,000 times in a method | 2.222 G | 2.102 G | -5.4% (a read: about 1,690 -> 1,310) |
| `@x = i`, 300,000 times | 2.014 G | 1.842 G | -8.5% |
| `C.new` setting three variables in `initialize`, 100,000 times | 5.022 G | 4.922 G | -2.0% |
| the same loop without the variable | 1.716 G | 1.710 G | |
| attr_accessor's reader and writer | 10.941 G | 10.941 G | (no ivar instruction) |
| so_object | 163.7 G | 161.6 G | -1.3% |

What is left of a read is mostly finding `self` in the frame (`lv_has` and `lv_get` of "self").

## Witnesses

Corpus 833:

- reads and writes at one instruction for objects of different shapes and classes in turn (a module's method included in three classes), and two classes sharing a shape;
- a variable removed, read and set again, last in the order;
- a frozen object's write refused, a class variable, an object with many variables and one whose area grows, dup and clone, `instance_eval`, a BasicObject, an Integer's refusal;
- an ISeq's `to_a` and `disasm` after its instructions ran.

It matches ruby on both executions with shapes on, off (`MERE_RUBY_SHAPES=0`) and bounded (`MERE_RUBY_SHAPES_MAX=8`).

Also here, #325's review: the comment on `cur_file_back`'s marked-name branch (a guard, not expected to run) and the call-depth tables' names in `map_set_si`'s comment.

CHECKED
