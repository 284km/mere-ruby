# A `return` out of a block (and a break, a next, a throw) runs through the
# interpreter's flow signals, which made two new Strings each time -- a kind
# and an "unhandled" message -- that ObjectSpace.each_object(String) found
# and GC.stat counted. One frozen String per kind is made once now.
GC.disable
def strings = (n = 0; ObjectSpace.each_object(String) { n += 1 }; n)
class C
  def r(n)
    [40, 80].each { |s| return s if n <= s }
    0
  end
  def b(n) = [1, 2, 3].each { |x| break x * n if x == 2 }
  def t(n) = catch(:done) { [1].each { throw :done, n } }
end
o = C.new
def count_strings(times)
  s0 = strings
  times.times { yield }
  strings - s0
end
3.times { o.r(50); o.b(2); o.t(3) }
base = count_strings(0) { }
[[:return, proc { o.r(50) }], [:break, proc { o.b(2) }], [:throw, proc { o.t(3) }]].each do |name, pr|
  p [name, count_strings(10, &pr) - base, count_strings(100, &pr) - base]
end
p [o.r(50), o.r(90), o.b(2), o.t(3)]
# ...and no String the program could find holds such a flow's own words
# ("returnret", "mere-ruby: (unhandled return out of a block)", ...). They
# are written as bytes here: a literal, or a Symbol, of the same text would
# itself be such a String
words = [
  [114, 101, 116, 117, 114, 110, 114, 101, 116],
  [98, 114, 101, 97, 107, 114, 101, 116],
  [99, 111, 110, 116, 114, 101],
  [118, 109, 106, 117, 109, 112],
  [109, 101, 114, 101, 45, 114, 117, 98, 121, 58, 32, 40, 117, 110, 104, 97, 110, 100, 108, 101, 100, 32, 114, 101, 116, 117, 114, 110, 32, 111, 117, 116, 32, 111, 102, 32, 97, 32, 98, 108, 111, 99, 107, 41],
  [109, 101, 114, 101, 45, 114, 117, 98, 121, 58, 32, 40, 117, 110, 104, 97, 110, 100, 108, 101, 100, 32, 98, 114, 101, 97, 107, 32, 111, 117, 116, 32, 111, 102, 32, 97, 32, 98, 108, 111, 99, 107, 41],
  [109, 101, 114, 101, 45, 114, 117, 98, 121, 58, 32, 40, 117, 110, 104, 97, 110, 100, 108, 101, 100, 32, 116, 104, 114, 111, 119, 44, 32, 116, 97, 103, 103, 101, 100, 41],
  [109, 101, 114, 101, 45, 114, 117, 98, 121, 58, 32, 40, 117, 110, 104, 97, 110, 100, 108, 101, 100, 32, 114, 101, 116, 117, 114, 110, 41]
]
found = 0
ObjectSpace.each_object(String) { |s| found += 1 if words.include?(s.unpack("C*")) }
p found
