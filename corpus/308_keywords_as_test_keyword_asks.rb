# Keyword arguments as CRuby's test_keyword asks them (note 330): a block
# made a method by define_method keeps its keyword defaults (they were all
# required ones); a block with keywords refuses one it does not name; **nil
# binds no local; a method with required keywords names them when the
# positional count is wrong; and a key that is no plain symbol is quoted.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message}"; end
  puts "#{n}: #{r}"
end
class K308
  define_method(:f4) {|str: "foo", num: 424242| [str, num] }
  define_method(:f5) {|str: "foo", num: 424242, **h| [str, num, h] }
  define_method(:f8) { |opt = :ion, *rest, key: :word| [opt, rest, key] }
  define_method(:m2) {|arg=nil, a: nil| [arg, a] }
  def f11(**nil) = local_variables
  def f12(**nil, &b) = [b, local_variables]
  def t1(x:) = x
  def t2(z, x:, y: 1) = z
end
k = K308.new
t(1) { [k.f4, k.f4(str: "bar"), k.f4(num: 1), (k.f4(str: "bar", check: true) rescue $!.message), (k.f4("s") rescue $!.message)] }
t(2) { [k.f5, k.f5(str: "a", z: 1)] }
t(3) { [k.f8, k.f8(1), k.f8(1, 2), k.f8(1, key: 3)] }
t(4) { [k.m2({"a" => 1, a: 1}), (k.m2(**{"a" => 1, a: 1}) rescue $!.class)] }
t(5) { [k.f11, k.f12] }
t(6) { [(k.t1(42) rescue $!.message), (k.t2 rescue $!.message), (k.t2(1, 2, x: 1) rescue $!.message)] }
t(7) { [].sample(random: nil, "invalid-argument": nil) }
p1 = proc {|str: "foo", num: 424242| [str, num] }
t(8) { [p1[], p1[str: "bar"], (p1[str: "bar", check: true] rescue $!.message), p1["string"]] }
t(9) { [(proc {|a:| a}.call rescue $!.message), (proc {|a:| a}.call(a: 0, b: 1) rescue $!.message), (->(a:) { a }.call rescue $!.message)] }
t(10) { [[[1, {k: 2}]].map { |a, h| [a, h] }, [{k: 1}].map { |h| h }, [[1]].map { |a, k: 5| [a, k] }] }
o = Object.new; def o.to_r = Rational(5, 2)
t(11) { Time.at(o) }
