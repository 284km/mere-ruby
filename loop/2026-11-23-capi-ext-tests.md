# 2026-11-23: the test extensions' C API, first part (note 553 §7, PR-1)

main's last green CI (`2e2ab568`) has 881 RED; about 230 of them in the C
extension tests (`-ext-`, mkmf, rubygems' ext, `ruby/test_bignum`). This is
the first of the PRs that take them down (the plan is note 553 §7).

- **rb_rational_raw** keeps the pair as it is (42/2 stays 42/2): a request of
  its own (MR_RAT_RAW) makes the VRat without mk_rat_s's reduction. It
  refused such a pair before. **rb_gcd_normal** is rational.c's Euclid by
  remainders (it was in unsupported.c). test_rat: 4/4.
- **rb_str_normalize_ospath** (Apple only, as in file.c, capi/ospath.c):
  NFC by segments, the HFS+ ranges copied as they are, a bad byte U+FFFD;
  the composition is String#unicode_normalize(:nfc). test_normalize: 4/4.
- **rb_data_define(super, ...)** under a class Data.define made: Data's own
  ::define, bound to that class (the class has none: it is undefined there,
  as in ruby). test_data: 2/2.
- **rb_f_notimplement** methods: C's define_method notes them (MR_NOTIMPL),
  and the interpreter keeps them in capi_notimpl -- listed by methods(false),
  calling one raises NotImplementedError, and respond_to? (which then asks
  respond_to_missing?), method_defined? and its three kin say false;
  Method#inspect says "(not-implemented)". test_notimplement: 6/6.
- **mkmf**: MAKEFILE_CONFIG has libdir `$(exec_prefix)/lib` and exec_prefix
  `$(prefix)` as configure writes them (dir_config takes the lib basename
  from libdir). **ruby_init / ruby_setup** answer as they do in a running
  interpreter (return at once), so the import library has them and
  `have_func("ruby_init")` links. test_have_func 2/2, test_config 5/5.
  Not test_have_library (2): its archive takes a "lib" prefix from
  LIBRUBY_A, which is "" here -- and must stay equal to LIBRUBY, or mkmf
  links every extension against LIBRUBYARG (mkmf.rb's `LIBRUBY !=
  LIBRUBY_A`; tried, and the import library's stubs then answered C).

- **RHASH_TBL / rb_hash_tbl** (capi/hashtbl.c): C gets an st_table of its
  own, filled from the Hash (the same objects, the Hash's order, compared by
  #hash / #eql?, or by identity for compare_by_identity), which st.c's
  functions read and change. What C changed goes back to the Hash when the
  C call that asked ends (the Hash then has the table's pairs in its order);
  asked again in the call, the same table. Ruby code C runs in between sees
  the Hash as it was: the write-back is at the end of the call. test_update
  (st_update: insert, keep, delete, replace, the same key and value
  objects): 5/5.

Looked at and left for the later PRs (note 553 §7): rb_econv_str_append
(needs the rb_econv_t of an Encoding::Converter, which is no C data here --
the whole rb_econv_* family together), Bug 3571 (a C method has no frame in
the backtrace, and a C block is labelled `block in`), MyInteger (Integer's
to_f / <=> on a C subclass of Integer should raise NotImplementedError), the
scheduler's interrupt (an unblock function run by a signal), Bug 14834
(rb_tracepoint_new).

## Review of #170 (work2026-fd)

- **[Critical] the RHASH_TBL table was no root**: a value C made by a call
  and put only in the table lost its number to a collection before the
  write-back. Every key and value of a live table is a root now
  (mr_hash_tables_root_at, from capi/gc.c's mr_capi_roots).
- **[Major] the Hash and the table drifted apart during the call** (one
  write-back at the end, by clear and refill): the two are kept in step at
  every request C makes (core.c's mr_up). What C changed in the table goes
  to the Hash before the request (sync_out); after a request that can write,
  what the interpreter changed in the Hash comes back into the table
  (sync_in, only when it differs, so st_update's own callback finds its
  table as it left it). A guard keeps the syncs' own requests from syncing.
  capi/check: a value put only in the table survives GC.start in a block,
  the block's `h[:z] = 3` and a later rb_hash_aset both stay, and C finds
  :z in the table after the block -- on both sides.
- **[Minor] compare_by_identity compared handle bits**: the table compares
  with #equal? and hashes by #object_id; capi/check finds a Bignum key by
  the same object.
- **[Minor] rb_f_notimplement notes**: a later definition of the name clears
  the note (set_meth / set_fresh_meth), and C notes its own after defining;
  a class method looks up the superclass chain (Sub.respond_to? is false
  for Parent's); Method#inspect says "(not-implemented)" after the name and
  before the parameters, as proc.c does.
- **[Minor] RbConfig::CONFIG["exec_prefix"]** is the prefix, so the
  MAKEFILE_CONFIG libdir expands.
- **[Minor] rb_data_define**: 0 is Data; nil or any non-class is
  rb_class_new's TypeError; a class outside Data is refused by name
  (ruby builds a Data-shaped class under it -- not offered).
- **[Suggestion] op 29's comment** sits on op 29. Left: `Rational.raw(42, 2)
  + 1` is (22/1) here and (44/2) in ruby -- the arithmetic reduces.
- The count: 17 of the 28 target tests fail on main without this PR and
  pass with it (the body said 19, counting test_have_library's 2, which were
  reverted). The base is main c521aa58.
