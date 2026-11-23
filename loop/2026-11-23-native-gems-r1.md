# 2026-11-23: native gems' own suites, round 1 -- bcrypt, msgpack and websocket-driver as the reference; nio4r and sqlite3 close

The goal (note 558): the native gems Rails uses run their OWN test suites on
mere-ruby the way they run on ruby 4.0.9, and mere-ruby is fixed where they
differ. Installing them already worked; this round finds out whether they
work. Each suite is run by hand, one at a time, against the release tag's
sources, with the gem and rspec 3.13 installed into a GEM_HOME per side by
`gem install --local` (the environment tools/capi_gem_check.py uses).

## bcrypt 3.1.22 (rspec): 39 examples, 0 failures on both sides

`rspec spec` in the source tree. Before this round mere-ruby did not get
through rspec-core's own setup. What stood in the way, in the order it was
met -- none of it is in bcrypt; all of it is rspec meeting the interpreter:

- **Proc's reflection** (m_eval_leaf.mere is_proc_method):
  `Proc.method_defined?(:source_location)` was false, so rspec-core took its
  Ruby 1.8.7 path, which extends the block -- and **Proc#extend** was a
  NoMethodError (invoke_val_c0's extend arm did not take a VProc, though it
  already knew how to make a Proc's singleton class). corpus 891, 896.
- **A Method of a class's builtin class method** (rspec-support's
  ReentrantMutex: `NEW_MUTEX_METHOD = Mutex.method(:new)` under
  `def self.new = NEW_MUTEX_METHOD.call`) recursed to SystemStackError.
  `@~m_bi` WAS set on the Method (owner Class) and bi_meth_shadowed was
  true; the call went bi_meth_call's last arm, the hidden `__bi~new` alias,
  and the class-method dispatcher found the class's own `self.new` again --
  no class-method arm honoured bi_skip. Now: bi_meth_shadowed counts a class
  method the class wrote itself; bi_meth_call takes the bi_skip route for a
  class receiver; the user-`self.new` arms (plain and with a block) and the
  cls_meth_own arm consume bi_skip; the allocate and name builtin arms step
  aside for the class's own only when no skip is pending (sng_user_over).
  The blt_alias class-method arm's Class#new special case (allocate, then
  #initialize called by name: NoMethodError for a class without its own
  #initialize, `class << C; alias newobj new; def new = newobj; end`) is
  gone -- the bi_skip arm under it does it. corpus 890 (also: a skip is for
  one dispatch only, so the builtin's #initialize can still build an object
  whose class has its own `new`).
- **String.new(obj)** did not convert by #to_str (new_obj), and **Ripper**
  (lib/ripper_ext.rb) refused a source with #to_str ("wrong argument type")
  where the C core StringValue's it; Ripper.lex lexed it as its #to_s. Every
  rspec failure report crashed on it: the snippet extractor hands
  Ripper.sexp an RSpec::Support::EncodedString. m_prism_lib.mere is
  regenerated (tools/gen_prism_lib.rb). corpus 892, 893.
- **An object's own #instance_exec** lost to the builtin when called with a
  block (invoke_with_block0). rspec-core's Example#instance_exec hands the
  block to the example group instance; every before hook ran with the
  Example as self, so `@salt` set in `before` was nil in the example -- the
  eight "failures" bcrypt showed once rspec ran. corpus 894.
- **A qualified constant's head** inside a class made by assignment and
  reopened (`SummaryNotification = Struct.new(...)`; `class
  SummaryNotification`) missed the lexical scope: `Formatters::Helpers` was a
  NameError while `Formatters` resolved. The head is now read as a bare name
  is when the key walk misses it (eval_e's EConst scoped arm). corpus 895.
- **Frames**: `load` ran its file with no frame -- its top level read
  '<main>' and there was no 'Kernel#load' -- and a block run as class-body
  statements (class_exec, module_exec, Class.new, Module.new) had no frame,
  so a block written inside it was one level short. rspec loads spec files
  and runs describe blocks with module_exec: its "Called from" line said
  'block in <main>' for ruby's 'block (2 levels) in <top (required)>'.
  rb_load runs under in_scope_frame_pass (a throw across load still reaches
  its catch) inside with_builtin_frame "load"; register_class_blk pushes a
  block frame (blk_frame_push) on its env. corpus 897.

After these the whole output equals the reference's but for the timing line.

## msgpack 1.8.7 (rspec): 462 examples, 0 failures, 1 pending on both sides

`rspec -f progress spec/*_spec.rb spec/cruby/*_spec.rb` (the Rakefile's
pattern for MRI). One failure first:

- **A Kernel function called where privacy does not apply** (send, a Method
  of it, bind_call) went to the receiver's #method_missing before Kernel's
  function. `unpacker: method(:Integer)` is taken inside an rspec example,
  whose method_missing refuses every DSL name ("`Integer` is not available
  from within an example"). Ruby asks method_missing only for a REFUSED
  private call, so the class's and the singleton's method_missing arms in
  the object dispatcher now step aside when vischeck is off and the name is
  the object's Kernel function (kernel_fn_here, which the Kernel arm under
  them uses too). corpus 898.

It is slow: 3 min 50 s against 10.7 s. Three examples are most of it:
unpacker_spec "frozen long strings" (106 s: feed_each over 10,240 copies of
the sample object -- the objects are built through the C API), "gc mark"
(20 s, a GC.start per byte) and factory_spec's "under stressful GC" (18 s).

## websocket-driver 0.9.0 (rspec): 205 examples, 0 failures on both sides

The spec helper requires bundler/setup; its Gemfile's `gemspec` wants the
development dependencies (eventmachine, permessage_deflate), which are not
installed, so both sides run with BUNDLE_GEMFILE pointing at a Gemfile of
`websocket-driver 0.9.0` and `rspec ~> 3.13` from the per-side gem home.
The native websocket_mask.bundle is the one loaded. One failure first:

- **`name [array] op rest`** with no comma after it parsed as
  `name([array]) op rest`: hybi_spec's `expect(@bytes).to eq [0x81, 0x7e,
  0x00, 0xc8] + [0x48, 0x65, 0x6c, 0x6c, 0x6f] * 40`. m_parse.mere builds
  both readings (EAmbigIdxC, as for a chain after the bracket):
  leftmost_arr_swap puts `name[array]` where the argument's leftmost operand
  is, for the reading where name is a local. corpus 899. (`name [1].size +
  1` -- a chain THEN an operator -- is still `name([1].size) + 1`.)

## nio4r 2.7.5 (rspec): 110 of 112 (reference 112, 1 pending on both)

`rspec --seed 1` (the repo's .rspec: documentation format, random order,
warnings). Two failures, one cause: **rb_thread_call_without_gvl runs the
function on the one native thread** (capi/system.c, as capi/README.md says:
"nothing else runs meanwhile"). nio4r's libev polls under it, so a Thread
blocked in `selector.select` holds every other Thread off:
selector_spec "wakes up if signaled to from another thread" and "selects
closed IO objects". Standalone, `Thread.new { sel.select }` then
`sel.wakeup` from the main thread never returns. Making it right means
running the function off the scheduler's thread and parking the calling
green thread until it returns (with the ubf to interrupt it) -- a change to
the threading model, not made here. The suite also takes 2 min 16 s against
8.7 s.

## sqlite3 2.10.2 (minitest): the reference's failures plus 7, of 410

Installed as capi_gem_check.py does (`-- --enable-system-libraries`), with
minitest 6.0.0 from the reference's bundled gems; the test files are
required in one process with `--seed 1` (the Rakefile's task is rake's
TestTask). The seven tests that build a 2 GiB String
(`/longer_than_int_max/`) are excluded on both sides: mere-ruby claims
RUBY_ENGINE "ruby", so the helper's "only CRuby allocates this string
cheaply" skip does not apply, and the C API mirror copies the bytes -- the
process was killed. The reference itself has 9 failures and 2 errors here
(the forking tests: macOS's system libsqlite crashes in the forked child,
on the reference too).

Before: the first GC.start after `Database#collation` was a fatal
"[BUG] C API: called with no call from the interpreter in progress".
**A dmark that runs between C calls** has nobody to ask: sqlite3's
database_mark walks its arrays with RARRAY_LEN / RARRAY_AREF, and its
aggregator pin calls rb_ivar_get. refresh_head and rb_mere_array now answer
the struct as last fetched and mr_callv answers nil while
mr_capi_mark_unasked (capi/mirror.c, capi/core.c); what those reads reach
is reachable from the object the dmark already marked, which the
interpreter marks. capi/check: Bug::ReadingBox (typed_fixture.c), whose
dmark reads both ways; typeddata contracts 94 on both sides.

After: 410 runs, 16 failures, 2 errors, 23 skips (reference 9, 2, 17). The
reference's 11 fail on both. The 7 more:

- ObjectSpace.dump has no "struct" for a typed data object
  (TestDatabase / TestStatement#test_typed_data_struct_name: nil).
- GC.stat(:total_allocated_objects) moves by 2 for a Statement#step that
  allocates nothing in CRuby (test_step_does_not_allocate_when_done).
- one GC.start does not release what the C side let go of: four tests count
  `ObjectSpace.each_object(Comparator / aggregator)` and see 2 for 1. A
  second GC.start brings it to 1. The same is true of a plain Ruby object
  (`a = [Plain.new]; a = nil; GC.start` leaves it), so this is the
  collector's precision, not sqlite3's.

The 6 more skips are the GC-compaction tests (GC.compact is not
implemented, by design). All of these are tests the gem guards with
`RUBY_ENGINE == "ruby"` as CRuby-specific.

## Not reached

puma 8.1.2 and nokogiri 1.19.7 (minitest) -- this round stopped at sqlite3.

Left as found (not needed by bcrypt, noted for later):

- `Class.new { raise }` has no 'Class#initialize' frame (nor Module's).
- `class Q < Queue; def self.new(*a) = super; end` -- `super` from
  `self.new` builds through new_obj_wb, which does not make a Queue
  ("not initialized"). The captured-Method route goes through the
  dispatcher and is right.
- `Ripper.new(src).class` is Prism::Translation::Ripper (ruby: Ripper).
- a captured builtin class method other than `new` called WITH a block on a
  class that overrides it (invoke_with_block0's generic singleton arm) still
  reaches the override.

## Review of #178

Fixed in this round (main merged first):

- **Major: a saved class `==` / `!=` overflowed the stack** -- the
  `(VClass _, _) -> skip9 ()` arm sent every class receiver back by name,
  and the class arms for `==` / `!=` never read bi_skip. bi_meth_call now
  answers a class's `==` (identity) and `!=` (the negation of the class's
  own `==`) itself, and its `===` as Module#=== (the Method had recorded
  Kernel's). corpus 900 covers `==`, `!=`, `<=>`, `===`, `<`, `to_s`,
  `hash`, `inspect`.
- **Major (from Rails-1): Time's saved `new` under a singleton
  replacement** -- `alias_method :__orig_new, :new` then
  `define_singleton_method(:new)` recursed (main: "already initialized
  Time"). The builtin-class override arm consumed bi_skip as it declined,
  and the `self.new` arm after it took the override. invoke_val_c0's VClass
  arm takes the skip once where it starts (bi_skip_take) and its arms read
  that. An alias of a builtin class method called with a block now keeps
  the block (invoke_with_block0). corpus 902 (Time, String, Array). None of
  #172's four arms is touched.
- **Major: `super` from an instance_exec / instance_eval override** --
  super_missing runs the builtin arm once, with the block, past the
  override (bi_skip). corpus 901.
- **Major: the dmark nil** -- a dmark run between C calls no longer gets a
  made-up nil. An internal ivar (no `@`: only C writes it) is read as C last
  wrote or read it, kept on the mirror and marked with it; any other ask of
  the interpreter there is mr_fatal, named as a dmark's. The fixture marks a
  C-only child conditionally on that read; typeddata contracts 102 on both
  sides and under MERE_RUBY_GC_STRESS=1.
- **Minor: `defined?(Fmt::H)` / `Fmt::Nope`** in the reopened class:
  defined? asks the nesting as the read does, and the head's const_missing
  is called. corpus 903.
- **Minor: Proc#extend's neighbours** -- a frozen proc refuses it,
  `M === pr` sees the singleton, `singleton_methods` lists the extended
  modules' methods. corpus 904.

The full check of that round found one regression: corpus 717's
`EnumeratedParent.native_children { }` -- an alias of the builtin
`subclasses`, called with a block, under a Ruby `subclasses` -- reached the
override, through the with-block alias arm added for `Array.on(2) { }`.
That arm now takes only an alias of `new` (whose with-block arm reads the
skip); 717 matches again on the evaluator and the VM.

Follow-ups, not done:

- The parser's `name [array] op rest` (corpus 899) still keeps the old
  reading for `p(foo [1] == [1] ? :yes : :no)` (leftmost_arr_swap answers
  false for a ternary) and `z = foo [1] + [2] do |q| q end` (a SyntaxError
  here). corpus 899 passing under MERE_RUBY_VM=1 is no evidence for this
  arm: the VM compiles the file itself, and a binary without it passes 899
  there too.
- A dmark with no C call in progress still cannot read a String
  (RSTRING_PTR), a Hash (rb_hash_foreach), an `@` ivar or call a method:
  those are refused (mr_fatal), not answered. An Array is read as last
  fetched, and one never fetched reads as empty.
- `K.method(:===).owner` says Kernel for a class (ruby: Module).
- An `M#call` on an extended proc that calls `super` overflows the stack
  (older: `def pr.call(*a) = super` does too).
