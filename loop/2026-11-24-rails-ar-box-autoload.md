# Autoloads are kept per box, as constants are

**Why.** Main's CI, compared file by file with the last complete run, had one test of `ruby/test_box.rb` go RED: `TestBox#test_calling_root_box_methods_does_not_change_user_boxes_newly_created`. It does this, with `RUBY_BOX=1`:

```ruby
require 'pathname'
Pathname.new('.').find { |path| path.directory? }
Ruby::Box.root.eval("require 'pathname'; Pathname.new('.').find { |path| path.directory? }")
```

The last line raised `NameError: uninitialized constant Pathname` from `pathname.rb:1`.

**The cause.** Pathname is core in ruby 4.0, and here it is an autoload: the constant names an internal file that defines the class. Since #90, `pathname.rb` begins with a bare `Pathname`, which fires that autoload before the file extends the class. A box keeps its own constants. The journal (`bx_note`, `bx_out`, `bx_in`) notes each write and puts the other box's values back at a switch. The autoload table had no journal. The main box loading Pathname removed the entry for every box. In the root box the constant was back to "not defined", as at boot, but its autoload was gone, so the bare `Pathname` had nothing to load.

**The change.**

- **The table has two doors.** `autoload_tbl_put` and `autoloads_del` are the only writers of `autoloads`. Each notes the write in the box journal (`bx_note_al`, kind `a`), under the rule the constants use: a top-level name, or a name under a class the boot knows.
- **A switch restores it.** `bx_switch` takes the leaving box's autoloads out and puts the entering box's in, beside the constants.

So an autoload a box loads, or registers, is that box's alone: Pathname, Set, Data, and a program's own `autoload`.

**Corpus 961** runs a child with `RUBY_BOX=1`. It has the test's shape (main loads Pathname, then the root box requires it and a new box calls `Pathname()`), and a program's own autoloads: one registered in main is not a new box's, and one a box registers and loads is not main's. It matches ruby 4.0.9 with and without `MERE_RUBY_VM=1`. On main's build it stops at the root box's `require`.

**Checked.**

- `ruby/test_box.rb`, both sides: 65 tests, MATCH 34, RED 1, BOTH 30. The RED is `test_prelude_gems_and_loaded_features`, which was RED before the regression too (ruby preloads bundled_gems and error_highlight at boot). The regressed test matches again.
- `run_corpus.sh --both`: 846/846. `MERE_RUBY_VM=1 run_corpus.sh --both`: 846/846.
- The source gates: dead_defs, dup_defs, gc_roots, meth_writes, name_len, ns_names, bracket_depth.

**Left, as on main.** Two boxes that each define a class of the same name share it. A class is known by its name, and the journal keeps a box's constants only at the top level or under a class the boot knows. So when a second box autoloads a file a first box already loaded, it finds the first box's module. The file does not run again there, and the registration stays. ruby gives each box its own class. This is the box design's limit, not the autoload table's.
