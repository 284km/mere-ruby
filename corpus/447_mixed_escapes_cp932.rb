# -*- coding: cp932 -*-
# Mixed escapes in a Shift_JIS source: a \u and the file's own characters
# in one literal piece are a SyntaxError; across an interpolation they meet
# at run time, where joining them is an Encoding::CompatibilityError (and in
# a regexp, two interpolated pieces disagreeing are too).

def show(label)
  yield
  puts "#{label}: no error"
rescue Exception => e
  puts "#{label}: #{e.class}"
end

show("one piece") { eval %q("あ\u1234") }
show("one piece, \\u first") { eval %q("\u{1234}あ") }
show('across #{}') { eval %q("\u{1234}#{nil}あ") }
show('across #{}, sjis first') { eval %q("あ#{nil}\u1234") }
show("regexp pieces") { eval %q(/#{"\u1234"}#{"あ"}/) }
show("regexp literal") { eval %q(/\u{1234}#{nil}あ/) }
