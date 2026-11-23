# C API: String internals -- the struct C sees in a slot, its buffer, and GC::INTERNAL_CONSTANTS

## 2026-11-23: a String's bytes in the struct C sees, and the room in its buffer

Note 553 §7.2's PR-2 (String internals for test/-ext-/string). The mirror
(capi/mirror.c) now keeps a String the way CRuby does, instead of always in
a buffer twice as long as needed:

- **In the struct while it fits.** RSTRING_NOEMBED is clear and the bytes
  are in as.embed.ary when they and the terminator fit in the struct's own
  16 bytes (sizeof(struct RString) - offsetof(as.embed.ary): CRuby's
  smallest slot); otherwise as.heap.ptr. C reads the flag before it asks
  for the bytes (RSTRING_PTR tests it first), so where they are is settled
  when the head is refreshed: MR_DESCRIBE now carries a String's bytesize
  (from bit 32: below it #160's encoding index and coderange bit). A
  String with no bytes fetched yet goes where it fits; one in the
  struct that Ruby grew past it moves out then; one in a buffer stays there
  until rb_str_resize brings it back (string.c's rule).
- **Buffers as long as asked.** A fetched String's buffer is its length
  (was: 15, 31, 63 ... and zero-filled). rb_str_modify_expand and
  rb_str_buf_new make exactly the room (RESIZE_CAPA_TERM), rb_str_cat grows
  2 * capa + termlen (str_buf_cat4), rb_str_resize follows string.c (back
  into the struct when it fits, cut down when longer than the length by more
  than min(length, 1 KB)). New room is not cleared, only the terminator's
  place at its end: test_modify_expand_memory_leak asks for the process's
  VSZ (416 GiB on macOS) ten times, and the old memset touched every page --
  the 10 s timeout. Now 0.24 s, VSZ 1.99x (limit 2.5).
- **The room the interpreter asks for.** `String.new(capacity: n)` and a
  read into a buffer (File#read / #sysread with a buffer: io.c's
  io_setstrbuf) call mr_capi_reserve (m_capi.mere's capi_reserve; a new
  extern, stubbed in m_capi_none.mere): the String's buffer is made that
  long the next time C looks at it. The interpreter's own String has no
  buffer to make longer, so nothing is asked while no C has run.
- **A buffer C puts in as.heap.ptr** (ext/-test-/string's cstr_noembed) is
  taken over and freed with the struct (the mirror's own was leaked); a
  pointer moved inside the mirror's buffer (unterminated_substring) keeps it.
  The length check at write-back reads as.heap.aux.capa, which C may set.

test/-ext-/string: test_s_new_capacity, test_io_read, test_modify_expand
(both) and test_cstr's test_rb_str_new_frozen_embed pass; no file lost a
test (all 94 test/-ext- files, against main's binary). capi/check/api.rb:
10 contracts (a String Ruby grows between two looks from C, rb_str_cat of
its own bytes out of the struct, rb_str_buf_new, rb_str_modify_expand's
exact room, rb_str_resize out and back, String.new(capacity:), a read into a
buffer), the same on both sides.

The other 15 of the 17 tests compute their sizes from GC::INTERNAL_CONSTANTS
(BASE_SLOT_SIZE, RBASIC_SIZE, RVARGC_MAX_ALLOCATE_SIZE) or ObjectSpace.dump's
slot_size, and stopped at nil before any C ran: the next section.

## 2026-11-23: GC::INTERNAL_CONSTANTS describes the slots the String structs C sees are allocated in

**Applying the 11-16 decision (real values only), as the user confirmed on
11-23 and 11-24.** On 11-16 INTERNAL_CONSTANTS was empty because there was no
slot heap (note 545 §2), checked by corpus 669 / 711. The values are real now
because the C side really allocates slots: INTERNAL_CONSTANTS reports the
slots the String mirrors C has seen are allocated in, and no slot is
predicted for an object C has not seen (11-24, #189's review). It describes
how the objects C sees are actually allocated,
as CRuby's MMTk build reports its own collector's values (gc/mmtk/mmtk.c) --
and for that to be true, not invented, the String mirror allocates that way:

- **Five slot sizes, 40 / 80 / 160 / 320 / 640 bytes** (five words and its
  doublings, CRuby's variable-width allocation). A String's struct is the
  first `slot` bytes of the mirror's `as`, and the block is allocated that
  long (str_take_slot). The slot is the smallest that holds the header
  (offsetof(struct RString, as.embed.ary), 24), the bytes and the
  terminator, chosen once -- the first time C sees the String, from its
  length or the room asked for -- and never changed, as an object's slot is
  not in CRuby; past 640, or for rb_str_init's capacity ("make noembed
  always"), the smallest slot and a buffer. Embedded capacity is slot - 24 -
  termlen; the largest embedded String is 640 - 24 - 1 = 615 bytes.
- **INTERNAL_CONSTANTS** = {BASE_SLOT_SIZE: 40, RBASIC_SIZE: 16,
  RVALUE_OVERHEAD: 0, RVARGC_MAX_ALLOCATE_SIZE: 640, SIZE_POOL_COUNT: 5},
  asked of the C side (mr_capi_layout: slot_sizes[], sizeof(struct
  RBasic)); MMTk's keys, MMTk's SIZE_POOL_COUNT name. Not HEAP_COUNT, page
  sizes or OLD_AGE: the interpreter's own values have no slot heap and the
  collector is not generational, so stat_heap stays empty. The Wasm / RV
  tree (no C side, m_capi_none.mere) answers 0 and the Hash is empty.
- **ObjectSpace.dump** of a String C has seen has "slot_size" and
  "embedded" (CRuby's places: after "type", after "frozen"), and
  **memsize_of** it is its slot plus its buffer (mr_capi_str_layout). A
  String C has not seen has no struct and no slot: the dump says nothing of
  one, and memsize_of is main's estimate (`__slot(24 + bytesize + 1)`), as
  for every other object. (The first version predicted the slot C would make
  when it first looked -- a value of a struct that does not exist; #189's
  review. Removed 11-24.)
- **String#freeze resizes** (rb_str_freeze calls rb_str_resize to the
  length): a frozen String's room asked for is dropped, and a buffer longer
  than its length by more than min(length, 1 KB) is cut down, or the bytes go
  back into the slot. `-s` is a new frozen String here, sized to its length.
  **OBJ_FREEZE / rb_obj_freeze do not** (CRuby sets the flag alone, and C may
  hold RSTRING_PTR across it): rb_obj_freeze marks the mirror
  (frozen_by_c) before the interpreter freezes the String, and the head
  refresh then leaves its buffer as it is; rb_str_freeze resizes first and
  then calls rb_obj_freeze, as string.c does. capi/check/api.rb: a pointer
  taken before OBJ_FREEZE still reads the bytes, the 1,024 bytes of room
  stay, and rb_str_freeze puts 3 bytes back in the smallest slot (room 15 on
  both sides). (#189's review, 11-24.)
- corpus 669 / 711 now check the constants are frozen and either these
  values or empty (the build without C); the reference takes the other
  branch (its GC compacts), so the programs print what they printed.

test/-ext-/string (11-24, after the review): test_capacity 8 of 10 (main
1), test_set_len 5 of 6 (main 0). Left: the shared Strings --
test_capacity_shared, test_set_len#test_shared, test_rb_str_dup x2: a
String that shares another's buffer (STR_SHARED, as.heap.aux.shared) is not
made here, rb_str_dup copies -- and test_encode_bang_capacity_with_
multibyte_terminator, which takes the smallest slot from
`ObjectSpace.dump("")`, a String C has not seen (it passed on the predicted
slot). test_ellipsize, test_enc_str_buf_cat and test_fstring fail as on
main.

Elsewhere: test_struct 2 errors -> 0 (it sizes Strings from
RVARGC_MAX_ALLOCATE_SIZE), test_file_exhaustive's test_expand_path_memsize
passes. ruby/test_string keeps main's 2 errors: test_string_interpolations_
across_heaps_get_embedded (both classes) reads slot_size from the dump of
Strings C has not seen (it passed on the predicted slot). objspace:
test_dump_includes_slot_size, test_dump_to_default and test_dump_to_io stay
in the exclusion ledger, with the reason now "asserts the default GC's slot
for a String C has not seen" (BASE_SLOT_SIZE exists now; the old reason no
longer held). test_gc, test_gc_compact, test_time, test_objectspace
unchanged.

**test_memsize_of_all: memsize_of makes no Strings.** The test compares
`memsize_of_all` with `memsize_of_all(String)`, counted one after the
other, so Strings the first count makes are counted by the second. Here
`memsize_of` of an Encoding, an Array, a Proc ... made 2 Strings each (~6,000
in the file's run: 3.4 M vs 4.5 M), and whether the first count won
depended on the order and on when the collector ran -- main's binary fails
it alone (`-n test_memsize_of_all`) and passes it in the file; this branch,
before the fix, the other way round. The Strings came from `__slot`'s
`return` out of an `each` block: **a return out of a block makes 2--3
Strings** on the evaluator and the VM (`def m(n) = ([40, 80].each { |s|
return s if n <= s }; 0)`, 10 calls: 31 / 21 Strings; the same without the
`return`: none). `__slot` is now a chain of comparisons, and memsize_of of
none of 14 kinds (Encoding, Array, Proc, Object, Hash, String, Range,
Method, exception, Time, Symbol, Class, Regexp, Bignum) makes a String.
test_memsize_of_all passes alone and in 10 runs of the file. The file fails
the same 8 tests in each run, all of which main's binary fails too (main: 9,
the ninth test_dump_to_io, which main runs unexcluded in this tool; after the
review the three dump tests are excluded again and the file is 46 tests, 8
failures). One of the first three runs had 1 error
more; it did not come back in the next 7, and its log was not kept, so which
test it was is not known.
**Follow-up (interpreter): a `return` from a block should make no
Strings** -- it is on every early return out of `each` / `map` / `find`
with a block.

memsize_of a String itself asks for one Integer (`__str_layout(s,
:memsize)`), no Array.

capi/check/spec_expect.tsv re-recorded: class_spec 103 -> 109 on the
mere-ruby side, which main's binary already passes (#157/#158, not this
change).
