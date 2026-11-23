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
