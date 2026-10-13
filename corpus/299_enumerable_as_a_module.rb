# Enumerable and Enumerator as CRuby's test_enum and test_enumerator ask them
# (note 321): an object that is Enumerable through its singleton class (or
# `extend`) answers min / sort / grep / chunk_while; the methods are the
# module's (#method, #owner, respond_to?, instance_methods, no helpers
# showing); a class with an #each and no Enumerable has none of them;
# min_by(n), each_slice's answer, chunk asked when walked, inject's count,
# to_a's keywords, tally's TypeError, a numbered _2 spreading an Array; and
# Enumerator's sizes, freeze, dup, with_object, inspect of keywords,
# StopIteration#cause, Generator / Yielder, a chain's + and with_index, and a
# bignum with_index offset.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message.gsub(/0x\h+/, '0x')}"; end
  puts "#{n}: #{r}"
end
o = Object.new
class << o; include Enumerable; def each; yield 3; yield 1; yield 2; self; end; end
x = Object.new; def x.each; yield 4; yield 2; end; x.extend(Enumerable)
t(1) { [o.min, o.max(2), o.sort, o.grep(1..2), o.uniq, o.minmax, x.min, x.reverse_each.to_a, x.chunk_while { |a, b| b == a + 1 }.to_a] }
class K; include Enumerable; def each; yield 2; yield 1; end; end
class N; def each; yield 2; end; end
t(2) { [K.new.method(:min).owner, K.instance_method(:sum).owner, K.new.respond_to?(:chunk), Enumerable.instance_methods(false).size, K.instance_methods & %i[__gather __arity! __each_all __enum_size]] }
t(3) { N.new.min }
t(4) { a = %w(albatross dog horse); [a.min_by(2, &:length), a.max_by(2, &:length), (1..3).min_by(2) { -_1 }, {a: 2, b: 1}.min_by(1) { _2 }] }
t(5) { [(1..10).each_slice(3) { }, (1..5).each_cons(3) { }, {a: 1}.each_slice(1) { }] }
t(6) { e = o.chunk { :_foo }; [e.class, (e.to_a rescue $!.class)] }
t(7) { [(o.inject rescue $!.message), o.inject(:+), (o.tally(BasicObject.new) rescue $!.message), ((1..1).zip(Object.new) rescue $!.message)] }
t(8) { y = Object.new; def y.each(foo:) = yield(foo); y.extend(Enumerable); [y.to_a(foo: 1), [[1, 2]].map { _2 }, (1..2).one?] }
t(9) { [1.step.each_slice(3).size, [].to_enum { 42 }.cycle.size, Enumerator::Product.new([], 1..).size, Enumerator.product(1.., 'a'..'c').size, (Enumerator.new("42") {} rescue $!.class)] }
t(10) { e = 3.times.freeze; [(e.next rescue $!.class), (e.rewind rescue $!.class)] }
t(11) { e = o.to_enum(:each); e.next; (e.dup rescue $!.message) }
t(12) { a = [2, 5, 2, 1, 5]; r = a.delete_if.with_object({}) { |i, seen| seen.key?(i) ? true : (seen[i] = true; false) }; [a, r.size, (0..2).each_with_object(a: 1).inspect] }
t(13) { e = [1].each; e.next; x0 = (e.next rescue $!); x1 = (e.next rescue $!); [x1.cause.equal?(x0), x1.result] }
t(14) { g = Enumerator::Generator.new { |y, v| y << 1 << 2; v }; acc = []; y = Enumerator::Yielder.new { |v| acc << v }; y << 5; [g.each(:bar) { }, g.to_a, acc, (Enumerator::Generator.new(1) rescue $!.message)] }
t(15) { c = [3].chain([4]); [c.with_index.to_a, (c + 5.step).class, (c + 5.step).first(4), [1, 2].each.with_index(1 << 63).to_a] }
