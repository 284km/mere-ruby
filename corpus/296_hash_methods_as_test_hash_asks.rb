# Hash methods as CRuby's test_hash asks them (note 318): a singleton's
# #default answers a missing key, a subclass's [] makes the subclass (with
# #to_hash conversion) and its to_h a plain Hash that keeps the default, an
# identity hash slices by identity and gives frozen copies of its String keys
# to a hash that is not one, replace counts before it asks frozen, eql? asks
# an object with #to_hash, flatten(0) is the pairs and a negative depth is
# every level, transform_keys! maps first and asks the block for the rest,
# transform_values! stores pair by pair, and a key's #hash that writes into
# the hash runs before the pairs are read.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message}"; end
  puts "#{n}: #{r}"
end
class SubHash < Hash; end
t(1) { x = {}; def x.default(k) = (self[k] = k * 2); [x[22], x] }
t(2) { h = SubHash[1 => 2]; h.instance_variable_set(:@x, 42); h.default = :d; [h.class, h.to_h.class, h.to_h.instance_variable_defined?(:@x), h.to_h.default, h.to_hash.class] }
t(3) { o = Object.new; def o.to_hash = {1 => 2}; [SubHash[o], SubHash[o].class] }
t(4) { h = {}.compare_by_identity; s1 = +"str"; s2 = +"str"; h[s1] = 1; h[s2] = 2; [h.slice(s1, s2).values, h.slice(s1, s2).compare_by_identity?] }
t(5) { {}.freeze.replace }
t(6) { o = Object.new; def o.to_hash = {}; def o.eql?(x) = true; def o.==(x) = true; [{}.eql?(o), {} == o, {} == Object.new] }
t(7) { key = +"a"; i = {}.compare_by_identity; i[key] = 0; h = {}.update(i); key.upcase!; [h.fetch("a"), h.keys[0].frozen?] }
t(8) { h = {}.compare_by_identity; h[+"x"] = 1; r = {}.replace(h); r.compare_by_identity? }
t(9) { a = {1 => "one", 2 => [2, "two"], 3 => [3, [["three"]]]}; [a.flatten(0), a.flatten(-1), a.flatten(2)] }
t(10) { a = {1 => 2}; a.flatten(nil) }
t(11) { x = {a: 1, b: 2, c: 3}; x.transform_keys!({a: :A, b: :B, d: :D}, &:to_s); x }
t(12) { x = {a: 1, b: 2, c: 3, d: 4}; begin; x.transform_values! { |v| x.freeze if v == 2; v.succ }; rescue FrozenError => e; end; [x, e.class] }
t(13) { x = {a: 1, b: 2, c: 3}; r = x.transform_values! { |v| break :stop if v == 2; v * 10 }; [r, x] }
obj = Object.new
obj.instance_variable_set(:@h, {})
class << obj; attr_reader :h; end
def obj.hash = (10.times { |i| @h[i] = i }; 0)
def obj.inspect = "test"
def obj.eql?(o) = o.class == Object
t(14) { h = obj.h; h[obj] = true; h.size }
t(15) { h = obj.h; obj2 = Object.new; def obj2.hash = 0; h[obj2] = true; h.delete(obj); h.size }
