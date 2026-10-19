# Formats, floats and ranges as test_sprintf, test_float and test_range ask
# (note 378): a flag after the width or the precision is refused, and so is a
# second name in one directive, in the format's encoding; Float#round settles
# a tie in the value's own scale; a number with underscores goes through
# ruby's 60-character buffer; a long hex fraction keeps its exponent; a
# Rational of big parts converts exactly; a nil step is a TypeError; an
# exclusive end with a negative step; Range#first is the begin; a delegator
# String range walks as Strings; and an index is a range only through all of
# #begin, #end and #exclude_end?, private ones too.
require "delegate"
def t(label)
  r = yield
  p [label, r]
rescue => e
  p [label, e.class, e.message]
end
t(:flag_after_precision) { sprintf("%.5+05d", 5) }
t(:flag_after_width) { sprintf("%5-d", 5) }
t(:named_after_named) { sprintf("%<key><key2>s", key: "v") }
t(:named_brace_after_named) { sprintf("%<key>{key2}s", key: "v") }
k = "〒".encode("euc-jp")
begin
  sprintf("%1$<#{k}>s", key: 1)
rescue ArgumentError => e
  p [e.message.encoding, e.message.bytes]
end
p sprintf("%<a>5.1f|%-6<b>s|", a: 1.25, b: "x")

p [5.015.round(2), -5.015.round(2), 1.255.round(2), 2.675.round(2), 0.5.round(1), 123.456.round(14)]
p Float(([1] * 10000).join("_")), ("1_" * 100 + "1").to_f, ("1" * 100).to_f
p Float("0x0." + "0" * 268 + "1fp2099"), Float("0x1.3494a9b171bf5p+144"), Float("-0x0p+0"), Float("0xf.fp0")
p Rational(1, 10**303) == 1.0e-303, (1..307).count { |n| 10.pow(-n) != Float::MIN.ceil(n) }
t(:float_nil_step) { 1.0.step(2.0, nil) {} }
t(:int_nil_step) { 1.step(2, nil) {} }
t(:string_step) { 1.step(2, "0.5") {} }

a = []
(0...-10).step(-2) { |x| a << x }
p a, (0..-10).step(-2).to_a
p [("a"..nil).first, (:a..).first, (2...0).first]
t(:beginless_first) { (..5).first }
t(:rational_each_size) { (1r..5).each.size }
r = (SimpleDelegator.new("9").."11")
p r.to_a, (SimpleDelegator.new("9")..).take(2), ("9"..SimpleDelegator.new("10")).to_a, r.include?("10")

o = Object.new
class << o; attr_accessor :begin, :end; end
o.begin = -10
o.end = 0
t(:no_exclude_end) { [][o] }
def o.exclude_end?; false; end
p [0][o]
class << o; private :begin, :end; end
o.begin = 0
o.end = 10
p [0][o], "abc"[o]
