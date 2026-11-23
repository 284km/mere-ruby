# A Struct's members are read and written by name with no String made: the
# keyword_init #new, #[], #[]= and #to_h spelled each member's slot name in
# Ruby ("@" + name + 1.chr), three Strings a member, which
# ObjectSpace.each_object(String) found and GC.stat counted
GC.disable
def strings = (n = 0; ObjectSpace.each_object(String) { n += 1 }; n)
KS = Struct.new(:a, :b, keyword_init: true)
PS = Struct.new(:a, :b)
k = KS.new(a: 1, b: 2)
s = PS.new(1, 2)
def count(times)
  3.times { yield }
  s0 = strings
  times.times { yield }
  strings - s0
end
base = count(0) { }
cases = {
  kw_new: -> { KS.new(a: 1, b: 2) }, kw_index: -> { k[:a] }, kw_index_set: -> { k[:b] = 3 },
  kw_to_h: -> { k.to_h }, pos_index: -> { s[0] }, pos_index_set: -> { s[:a] = 5 }, pos_to_a: -> { s.to_a },
}
cases.each { |name, pr| p [name, count(10, &pr) - base] }
p k, s, k.to_h, s[:a], k[:b]
k.freeze
begin
  k[:a] = 9
rescue FrozenError => e
  p e.class
end
p KS.new(a: 1).b, (KS.new(c: 1) rescue $!.message)
