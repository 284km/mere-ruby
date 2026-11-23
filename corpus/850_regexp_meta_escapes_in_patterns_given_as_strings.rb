# A \M- escape in a pattern given to Regexp.new is one byte, its top bit set,
# in a group and in a class. Inside a run of escaped bytes it can finish a
# multibyte character: '\xc3\M-)' is C3 A9, an "é". The pattern parser had
# no arm for \M-, so it took `M` and `-` as themselves. Its `)` closed a
# group that was never opened, and inside a class the `-` made a range.
def t(src, subject = nil)
  r = Regexp.new(src)
  p [src, r.source, r.encoding, subject && (r =~ subject)]
rescue RegexpError => e
  p [src, e.class, e.message]
end

t('\xc3\M-)', "café")
t('caf\xc3\M-)', "café")
t('(\xc3\M-))', "é")
t('[\xc3\M-)]', "é")
t('[a\xc3\M-)]+', "aéa")
t('\xc3\M-\C-)', "É")
t('\xe3\M-\x81\M-\x82', "あ")
# a meta escape that does not finish a character, or stands alone
t('\M-)')
t('a\M-)b')
t('\M-a')
t('\M')
t('\M-')
t('\Ma')
# control escapes, as Onigmo reads them for a string: `\c?` is 0x1F here
t('\c?', "\x1f")
t('\cA', "\x01")
t('\C-a', "\x01")
t('\c')
t('\C')
t('\C-')
t('\Ca')
p((Regexp.new('\c?') =~ "\x7f"), (/\c?/ =~ "\x7f"))
p Regexp.new('x\xc3\M-)y').match("axéyb")[0]
# (review of #168) only a UTF-8 pattern joins escaped bytes in a class: one
# made from a BINARY string keeps them, as /n does
def tb(src, subj)
  r = Regexp.new(src.b)
  p [r.encoding, r =~ subj]
end
tb('[\xc3\xa9]', "\xA9".b)
tb('[^\xc3\xa9]', "\xC3".b)
# a control or meta escape takes any escape after it, masks with 0x1F (no
# special `?`), and refuses a second of its kind or a non-ASCII byte
t('\c\x41', "\x01")
t('\c\\\\', "\x1c")
t('\c\e', "\e")
t('\xc3\c\M-)', "É")
t('[\xc3\c\M-)]', "É")
t('\xc3\M-\C-?', "ß")
t('\xc3\M-\c?', "ß")
t('\cé')
t('\C-\C-x')
t('\M-\M-x')
# \M- alone can name a non-ASCII character, and the Regexp is UTF-8, fixed
t('\M-C\M-)', "é")
t('[\M-C\M-)]', "é")
p Regexp.new('\M-C\M-)').fixed_encoding?
# (second review of #168) the compiled program is shared by every Regexp
# with the same source and options: a UTF-8 subject met first must not
# decide what a BINARY one meets, nor the other way round
r = Regexp.new('[\xc3\xa9]'); p [r =~ "a".b, r =~ "é"]
r2 = Regexp.new('[\xc3\xa9]'); p [r2 =~ "é", r2 =~ "a".b]
rb = Regexp.new('[\xc3\xa9]'.b); p [rb =~ "a", rb =~ "\xA9".b]
rb2 = Regexp.new('[^\xc3\xa9]'.b); p [rb2 =~ "z", rb2 =~ "\xC3".b]
rb3 = Regexp.new('[^\xc3\xa9]'.b); p [rb3 =~ "\xC3".b, rb3 =~ "z"]
rn = Regexp.new('(?<c>[\xc3\xa9])'); p [rn =~ "zé", $~ && $~[:c], rn.names]
