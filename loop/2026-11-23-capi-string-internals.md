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

**The decision changed** (the user's, 2026-11-23). On 11-16 it was "empty:
there is no RVALUE slot heap" (note 545 §2), checked by corpus 669 / 711. Now
INTERNAL_CONSTANTS describes how the objects C sees are actually allocated,
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
- **ObjectSpace.dump** of a String has "slot_size" and "embedded" (CRuby's
  places: after "type", after "frozen"), and **memsize_of** a String is its
  slot plus its buffer -- what its struct is, or will be made as when C
  first looks (mr_capi_str_layout). Other objects have no slot and say none.
- **Freezing resizes** (rb_str_freeze calls rb_str_resize to the length): a
  frozen String's room asked for is dropped, and a buffer longer than its
  length by more than min(length, 1 KB) is cut down, or the bytes go back
  into the slot. `-s` is a new frozen String here, sized to its length.
- corpus 669 / 711 now check the constants are frozen and either these
  values or empty (the build without C); the reference takes the other
  branch (its GC compacts), so the programs print what they printed.

test/-ext-/string: test_capacity 9 of 10 (embedded, normal, literal, frozen,
fstring, encode_bang now), test_set_len 5 of 6. Left: the shared Strings --
test_capacity_shared, test_set_len#test_shared, test_rb_str_dup x2: a
String that shares another's buffer (STR_SHARED, as.heap.aux.shared) is not
made here, rb_str_dup copies.

Elsewhere: ruby/test_string 2 errors -> 0 and test_struct 2 -> 0 (they size
Strings from BASE_SLOT_SIZE / RVARGC_MAX_ALLOCATE_SIZE), test_file_exhaustive's
test_expand_path_memsize passes. objspace: test_dump_includes_slot_size,
test_dump_to_default and test_dump_to_io pass on both sides and leave the
exclusion ledger (unittest/excludes-gc/TestObjSpace.rb, gc_cases.tsv now
MATCH). test_gc, test_gc_compact, test_time, test_objectspace unchanged.

**test_memsize_of_all is RED in the file's run, and why it is not this
change.** It compares `memsize_of_all` with `memsize_of_all(String)`,
counted one after the other. Here `memsize_of` of an Encoding, an Array, a
Proc ... makes Strings (206 for the Encodings alone, GC disabled), so the
first count makes ~6,000 Strings that the second then counts: 3.4 M vs 4.5 M
in the file's run, 0.96 M when the Strings are counted again right after.
Whether the first count wins depends on what the tests before it left and
when the collector runs: main's binary fails it run alone
(`-n test_memsize_of_all`) and passes it in the file; this branch passes it
alone and, with the three tests above now running (the order changes), fails
it in the file. The fix is a memsize_of that allocates nothing, not part of
this change. memsize_of a String itself asks for one Integer
(`__str_layout(s, :memsize)`), no Array.

capi/check/spec_expect.tsv re-recorded: class_spec 103 -> 109 on the
mere-ruby side, which main's binary already passes (#157/#158, not this
change).
