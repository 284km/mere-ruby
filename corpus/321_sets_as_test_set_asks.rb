# Sets as CRuby's test_set asks them (note 343): Set::CoreSet exists, a
# subclass that redefines #add gets new's elements through it, merge takes
# no keywords, ^ keeps the class and set.c's order, #reset rehashes, a set
# that contains itself hashes and compares as ruby's does -- and a Hash
# store asks a key for its #hash once.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message}"; end
  puts "#{n}: #{r.gsub(/0x\h+/, '0x')}"
end
class SS321 < Set; end
t(1) { [Set::CoreSet.ancestors.first(3), Set::CoreSet.superclass, Set::CoreSet.instance_methods(false)] }
t(2) { c = Class.new(Set) { def add(o) = (super; super(o + 1)) }; [c.new([1]).to_a, c[3].to_a, SS321.new([1, 2]).to_a] }
t(3) { [(Set[].merge(a: 1) rescue $!.message), Set[1].merge([2], Set[3]).to_a, Set[1].merge({x: 1}).size] }
t(4) { r = SS321[1, 2, 3, 4] ^ [2, 4, 5, 5]; [r.class, r.to_a, (Set[1, 2] ^ Set[2, 3]).to_a] }
t(5) { a = [1, 2]; b = [1]; s = Set.new([a, b]); b << 2; s.reset; [s.size, s.include?([1, 2])] }
t(6) {
  s1 = Class.new(Set)["a", "b"]
  s1.add(s1).reset
  s2 = Set["a", "b", Set["a", "b", s1]]
  [s1 == s2, Set[Exception.new, nil] == Set[Exception.new, Exception.new], s1.hash.class]
}
t(7) { c = Class.new(Set::CoreSet); c.set_temporary_name("_MySet"); d = Class.new(Set); d.set_temporary_name("_MySet2"); [c[1, 2].inspect, d[1, 2].inspect] }
t(8) { $n = 0; o = Object.new; def o.hash = ($n += 1; 5); h = {"a" => 1, "b" => 2}; h[o] = 1; a = $n; h[o] = 2; [a, $n, h.size, h[o]] }
