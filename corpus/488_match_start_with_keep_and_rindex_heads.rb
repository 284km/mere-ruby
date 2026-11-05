# `=~` answers where the successful attempt began, which a \K leaves behind
# the match's own start: `"xxfoo@b" =~ /[a-z]+\K@/` is 0 while begin(0) is 5.
# It answered begin(0). And String#rindex with a regexp tries its attempts on
# characters: one tried from inside a UTF-8 character matched that
# character's trailing bytes, and `"aあbあb".rindex(/[^ ]b/)` was 5, past the
# string's last index. The character counts of index / rindex were UTF-8's
# whatever the subject's encoding: a binary, ISO-8859-1, EUC-JP or UTF-16
# subject is counted in its own.
s = "xxfoo@bar.com yy baz@qux.com"
p s =~ /[a-z]+\K@/, $~.begin(0), $~.pre_match, $~[0]
p s =~ /foo\K@/, (/foo\K@/ =~ s), s.index(/foo\K@/), s.match(/foo\K@/).begin(0)
p "abc" =~ /b\Kc/, $~.offset(0), :abc =~ /b\Kc/
p "héllo@x" =~ /[a-zé]+\K@/, "あいう@" =~ /う\K@/
p "key_1 key_3999" =~ /key_\K3999/, "x" =~ /\K/, "ab" =~ /(?=b)\Kb/
case "abc"
when /b\Kc/ then p $~.begin(0)
end
t = "あいう key_9 えお key_3999 かき"
p t.rindex(/[^ ]+ key/), t.rindex(/key/), t.rindex(/[^ ]+ key/, 12), t.rindex(/え.\s/), t.rindex(/\S+ k/)
p "ああab".rindex(/.b/), "ああab".rindex(/[^x]b/), "aあbあb".rindex(/[^ ]b/), "aあbあb".rindex(/./), "あ".rindex(//)
p "aあbあb".rindex(/[^ ]b/, 3), "aあbあb".rindex(/[^ ]b/, 2), "éé".rindex(/é/), "éé".rindex(/\p{L}\z/)
p "aあbあb".rpartition(/[^ ]b/), "aあbあb".b.rindex(/.b/n)
u = "aéb".encode("UTF-16LE"); r16 = Regexp.new("b".encode("UTF-16LE"))
p u.index(r16), u.rindex(r16), u.index(r16, 1), u.byterindex(r16)
e = "あいkey_3いk".encode("EUC-JP"); r = Regexp.new("い.".encode("EUC-JP"))
p e.index(r), e.index(r, 2), e.rindex(r), e.rindex(r, 5), e.byteindex(r, 2), e.byterindex(r)
b = "aあbあb".b; p b.rindex(/.b/n), b.index(/.b/n, 3), b.byterindex(/.b/n), b.rindex(/b/n, 6)
l = "\xe9t\xe9 key_1".force_encoding("ISO-8859-1"); p l.rindex(/t./), l.index(/./, 2), l.rindex(/\w+/)
