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
