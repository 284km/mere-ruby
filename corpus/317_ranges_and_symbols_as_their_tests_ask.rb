# Ranges and symbols as CRuby's test_range and test_symbol ask them (note
# 339): a beginless range counts back for #last(n), a Symbol range steps by
# its String walk, an object at either end steps by + and <=>, a Rational end
# bounds an Integer walk, a frozen Range.allocate refuses #initialize,
# Symbol#=~ asks the other side, and Symbol#to_proc is one Proc per symbol.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message}"; end
  puts "#{n}: #{r}"
end
t(1) { [(nil..10).last(3), (nil..10).last, (..10).last(0), (nil...10).last(2), (0..10).last(3)] }
t(2) { a = []; (:a..:g).step(2) { a << _1 }; [a, (:a..).step(3).first(2), (:a...:e).step(2).to_a] }
N317 = Data.define(:v) { def coerce(o) = [o, v]; def <=>(o) = v <=> (o.is_a?(N317) ? o.v : o); def +(o) = with(v: v + o) }
t(3) {
  i = N317.new(100)
  s = ->(r, st) { a = []; r.step(st) { a << (_1.is_a?(N317) ? _1.v : _1) }; a }
  [s.(100..i, 10), s.(i..100, 10), s.(N317.new(5)..N317.new(5), 0), s.(N317.new(5)..N317.new(9), 2), (100..i).step(10).to_a]
}
t(4) { r = Range.new(1, 5r, true); a = []; r.each { a << _1 }; [a, r.to_a, (1..7/2r).to_a, (1..7/2r).map { _1 * 2 }, r.size] }
t(5) { r = Range.allocate; r.freeze; [(r.__send__(:initialize, 1, 2) rescue $!.message), (r.send(:initialize, 1, 2) rescue $!.class)] }
t(6) { a = (..5).step(1); [(a.to_a rescue $!.message), ((..5.0).step(1).to_a rescue $!.message), a.class] }
t(7) { [(("a"..).reverse_each.size rescue $!.message), ((.."z").reverse_each.size rescue $!.class), ("a".."z").reverse_each.size] }
t(8) { o = Object.new; def o.=~(x) = x + "bar"; [(:foo =~ o), ((:foo =~ "foo") rescue $!.class), :"FeeFieFoo-Fum" =~ /Fum$/] }
t(9) { [:itself.to_proc.equal?(:itself.to_proc), :itself.to_proc.lambda?, (:succ.to_proc.binding rescue $!.message), [1, 2].map(&:succ)] }
def sym317(src)
  eval(src).inspect
rescue SyntaxError
  :syntax_error
end
t(10) { [sym317(":="), sym317(":=="), sym317(":[]="), sym317(":=~")] }
