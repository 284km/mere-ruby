# Every String operation that counts, positions or pads works in CHARACTERS in
# Ruby, and this interpreter worked in bytes. On ASCII the two are the same, so
# nothing in the corpus showed it until a test used Japanese; enumerating the
# position/length methods against CRuby turned up nine at once, three of which
# returned strings that were not even valid UTF-8.
s = "日本語abcあ"
p s.length
p s.bytesize
p s.dup.insert(1, "X")          # was "\xE6X\x97\xA5..." -- inside a character
p s.center(10, "-")             # widths were counted in bytes, so nothing padded
p s.ljust(9, ".")
p s.rjust(9, ".")
p s.count("日本")               # was 6 (bytes) rather than 2
p s.delete("日")                # was a broken string
p s.tr("日", "X")               # was "XXXX\x9C\xAC..." -- one X per byte
p "ああい".squeeze
p "%-5s|" % "あ"                # the width again
p "あ".ljust(3, "x")
p s.match(/./, 2)[0]            # the position argument was in bytes
p s.slice!(0, 2)                # did not exist at all
p s

# casecmp folds ASCII only; casecmp? does the full Unicode folding
p "Ä".casecmp("ä")
p "Ä".casecmp?("ä")
p "A".casecmp("a")

# and the forms slice! accepts, which are String#[]'s forms
u = "abcdef"; p u.slice!(1); p u
v = "abcdef"; p v.slice!(1..2); p v
w = "abcdef"; p w.slice!("cd"); p w
x = "abcdef"; p x.slice!(/c./); p x
y = "abc"; p y.slice!(9); p y
