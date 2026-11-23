# A pattern given as a string: \M- is one byte, and escaped bytes in a class make one character (corpus 850)

**The gap.** `Regexp.new('\xc3\M-)')` was refused with "unmatched )". Ruby accepts it: `\M-)` is 0x29 with its top bit set, 0xA9, so the pattern is the bytes C3 A9, an "é". The check of the escaped runs (`rx_esc_runs_why`) already read `\M-` this way. The pattern parser (`rxp_escape`) had no arm for it, so it took `M` and `-` as themselves, and the `)` closed a group that was never opened. Inside a class (`rxp_class_atom`) the same `-` made a range. This was recorded in note 551 as a known gap; main had it too.

Looking at the class case showed an older gap under it. In a class, escaped bytes did not join into a character at all, so `Regexp.new('[\xc3\xa9]') =~ "é"` was nil. Each byte was a member of its own, and no single byte is a character of a UTF-8 subject.

**The change.**

- `rxp_escape` and `rxp_class_atom` read `\M-` (and a control escape nested inside it, `\M-\C-x`) with `rx_esc_byte`. That is ruby's read_escaped_byte, and the run check already uses it.
- `\c` and `\C-` keep their own arm, because a pattern given as a string is read by Onigmo and not by the parser. There `\c?` is 0x1F, while a literal's `/\c?/` is 0x7F (checked on ruby 4.0.9). Using `rx_esc_byte` for them too would have broken that. Their refusal now says what ruby says, "too short control escape", instead of "bad \C-". Their arithmetic no longer goes through `rxp_ord`, a search of the 256 one-byte strings, which is now gone.
- A class member written as an escaped byte that leads a UTF-8 character (0xC2 to 0xF4) takes the escaped continuation bytes after it, and the member is that character. A `/n` pattern keeps its bytes. If the escapes after the lead byte do not finish the character, the member stays the lone byte, as before.

**Witness.** corpus 850 covers:

- `\M-` finishing a character in a group, in a class, and in a `+` class;
- `\M-\C-x`;
- `\M-` that does not finish a character, or stands alone;
- `\c`, `\C-` and their refusals;
- the literal `/\c?/` next to `Regexp.new('\c?')`.

On main, the first seven lines differ from ruby.

## Review of #168: re.c's reader, and only a UTF-8 pattern joins

The review found two problems in the first version.

- **Joining was a regression for BINARY patterns.** The class join stopped only for the `n` flag, and a Regexp made from a BINARY string has no `n`. `Regexp.new('[\xc3\xa9]'.b) =~ "\xA9".b` is 0 on ruby and on main, and the first version gave nil. The join now happens only when the pattern is cut as UTF-8 (`cut_k`).
- **The new `\M-` arm used the parser's rule.** That is `rx_esc_byte`, under which `?` behind a control prefix is 0x7F. re.c reads a pattern given as a string with its own `read_escaped_byte`, which differs in three ways:
  - a control prefix only masks with 0x1F, so `\M-\C-?` is 0x9F;
  - `\c`, `\C-` and `\M-` each take any escape after them, so `\c\M-)` is 0x89, `\c\x41` is 0x01 and `\c\\` is 0x1C;
  - a second prefix of the same kind, or a non-ASCII byte after one, is refused.

**The change.** `rx_str_esc_byte` is that reader. These now use it:

- the check of the escaped runs (it returns the reader's refusal, so `\M-\M-x` says "duplicate meta escape");
- `rxp_escape`, for `\c`, `\C-` and `\M-` in one arm;
- the class members, where `\c` and `\C-` were themselves before;
- the continuation bytes of a joined class character;
- `rx_kinds` and `rx_src_nonascii`, so a `\M-` escape past ASCII makes the Regexp UTF-8 and fixed, as `\x` already did (`'\M-C\M-)'` was US-ASCII).

corpus 850 gained every case the review named.

## Second review of #168: the program cache decided by the first subject

Joining was decided by `cut_k`, which is set by the encoding of the subject being matched. The compiled program is cached under the pattern and its options, and that key did not say how it was cut. So whichever subject came first decided the program for every Regexp with that source: `r =~ "a".b; r =~ "é"` was nil, nil, and the other way round for a BINARY pattern.

Two changes make the cut part of the key.

- **The key says how the program was cut.** A UTF-8-cut program for a pattern with a class and an escape gets its own key (`rx_cut_key`, a `J8` suffix kept apart from the `/i` program's `U8`).
- **The plain key no longer gets a copy of a joined program.** `rxc_get` copies every program it compiles under a cut key to the plain key, for the readers that look up names and the group count by that key. A joined program is not the byte-cut one, and its start bytes differ too. So for it, the plain key gets only the names and an alias that `rx_ng_of` follows, and a byte-cut search compiles its own program.

I found the second one by tracing: with only the key changed, the BINARY search still found the joined program under the plain key.

The comment in `rx_esc_runs_why` now says that `'a\c\xff'` is a 0x1F, under re.c's reader.

corpus 850 has each order, for a UTF-8 and a BINARY pattern and for a named group.

## Third review of #168: the /i program

A `/i` pattern with `s`, `S`, `k` or `K` in it is keyed by the `U8` program before the `J8` branch is reached, and the copy to the plain key was stopped only for `J8`. So `Regexp.new('[\xc3\xa9]s'.b, Regexp::IGNORECASE)` met `"as"` first and then gave nil for `"\xA9s".b`; ruby gives 0. The copy is now stopped for any program compiled under a cut key, cut as UTF-8, from a pattern with a class and an escape, whatever the suffix. corpus 850 has both orders, and an `/i` UTF-8 pattern against `"éK"`.

The review also listed some older differences, noted here without a change:

- a pattern written only with octal escapes (`\303\251`) is US-ASCII here;
- BINARY `split`;
- the wording of the overlong and surrogate refusals.
