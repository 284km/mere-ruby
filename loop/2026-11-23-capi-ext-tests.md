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
