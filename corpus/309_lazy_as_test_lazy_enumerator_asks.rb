# Enumerator::Lazy as CRuby's test_lazy_enumerator asks it (note 331): the
# Enumerable methods ruby keeps lazy (cycle, each_slice, each_cons,
# each_with_object, each_entry, to_enum, slice_before / slice_after) stay
# lazy -- `lazy.cycle.map { }.first(5)` never returned -- a `break` in
# Lazy#each stops an endless source, a Range with a bignum end walks at all,
# and Array#zip with a block converts its arguments as zip without one does.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message}"; end
  puts "#{n}: #{r}"
end
class Step309
  include Enumerable
  attr_reader :current
  def initialize(enum) = (@enum = enum; @current = nil)
  def each(*args) = @enum.each { |v| @current = v; yield v }
end
t(1) { [1, 2, 3].lazy.cycle.map { |x| x * 2 }.first(5) }
t(2) { a = Step309.new(1..3); [a.lazy.cycle(2).map(&:to_s).first, a.current] }
t(3) { %i[slice_before slice_after with_index cycle each_with_object each_slice each_entry each_cons].map { |m| arg = {slice_before: //, slice_after: //, each_with_object: 42, each_slice: 42, each_cons: 42}[m]; [].lazy.send(m, *arg).class } }
t(4) { [(1..2**120).lazy.each_cons(2).first(2), (1..2**120).lazy.each_slice(2).first(2), [1, 2, 3].lazy.each_slice(2).to_a] }
t(5) { [[1, 2].lazy.each_with_object([]).to_a, [1, 2].lazy.each_with_object([]) { |x, m| m << x }] }
t(6) { r = []; x = (1..).lazy.each { |v| r << v; break :b if r.size > 2 }; [x, r] }
t(7) { r = []; (1..2**70).each { |v| r << v; break if r.size > 2 }; r }
t(8) { r = []; [1, 2, 3].zip("a".."c") { |x, y| r << [x, y] }; r }
t(9) { a = Step309.new(1..3); ary = []; [a.lazy.zip("a".."c") { |x, y| ary << [x, y] }, ary, a.current] }
t(10) { (1..10).lazy.take(-1) }
t(11) { [("a".."c").lazy.grep(/b/).inspect, ("a".."c").lazy.grep(/b/).to_a] }
t(12) { c = Class.new { def initialize(v) = @v = v; def to_ary = [:to_ary, @v] }; [1, 2].lazy.flat_map { |x| c.new(x) }.force }
t(13) { l = [1, 2, 3].lazy; def l.foo(*a) = (yield a; yield a); e = l.to_enum(:foo, :hello, :world); [e.class, e.to_a, [1, 2, 3].lazy.to_enum { 42 }.size] }
