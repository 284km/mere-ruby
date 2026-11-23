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
