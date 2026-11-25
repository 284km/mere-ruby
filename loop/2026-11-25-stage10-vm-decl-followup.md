# A declaration block read without side effects (#289's review)

Two suggestions of #289's review, made here.

**Reading a block changed nothing only if it was used.** `vm_def_block_body` read a VM block's program as the parsed form and, while reading, did what `vm_define` does besides defining: noted the line of the def's `end`, and marked the def's tree as one a method was defined from. At the `new` call it read every block of one def, before the proof. A block the proof refused runs, and `vm_define` does the same again, so nothing differed. But a block that is neither used so nor run, `Foo.new { def x; end }` with a `new` that ignores its block, left its tree marked, and a marked tree is not given back when the run ends. Reading is now only reading; `vm_def_block_mark` does the two things for each def of a parsed form that was used: at the `new` call once the proof holds, and in `make_anon_cls_block` once the writer took the def.

**The block's source and home.** `vm_class_def_block` now drops `pending_srcproc` and `pending_home` before the writer, as `native_include_body` and `register_class_blk0` do.

And an unused binding in the `refine` form is gone.

Corpus 825 gains `Foo.new { def never_made; end }` with a `new` that ignores the block: the method is defined nowhere, as in ruby. Instructions on the VM are #289's (13.01 G for 300,000 `Class.new { def }`, 28.6 G for the leak test's loop).

CHECKED
