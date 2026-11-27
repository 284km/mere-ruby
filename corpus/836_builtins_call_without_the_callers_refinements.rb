# A builtin's own calls see no refinement, as a C body's rb_funcall sees
# none: `sum` adds with Integer's +, `sort` compares with the class's own
# <=>, a Hash keys with the class's own hash and eql?, format writes with the
# class's own to_s, whatever the file that called them has refined. The
# calls the program writes itself -- and the blocks and methods the builtins
# run -- keep the refinements of where they were written.

class V836
  include Comparable
  attr_reader :n
  def initialize(n) = @n = n
  def <=>(o) = n <=> o.n
  def ==(o) = o.is_a?(V836) && n == o.n
  def eql?(o) = self == o
  def hash = n.hash
  def to_s = "v#{n}"
  def inspect = "V#{n}"
  def coerce(o) = [V836.new(o), self]
  def +(o) = V836.new(n + (o.is_a?(V836) ? o.n : o))
  def succ = V836.new(n + 1)
end

class W836
  def to_ary = [1, 2]
  def to_a = [3]
  def to_hash = {w: 1}
  def to_str = "w"
  def to_int = 1
  def to_proc = proc { :wp }
end

module IntOps836
  refine Integer do
    def +(o) = :refined_plus
    def <=>(o) = 0
    def to_s = "R"
    def dbl = self * 2
  end
end

module VOps836
  refine V836 do
    def <=>(o) = -(n <=> o.n)
    def ==(o) = true
    def eql?(o) = true
    def hash = 1
    def to_s = "refined_v"
    def coerce(o) = raise("refined coerce")
    def +(o) = :refined_plus
    def succ = raise("refined succ")
  end
end

module WOps836
  refine W836 do
    def to_ary = [:r1, :r2]
    def to_a = [:ra]
    def to_hash = {r: 1}
    def to_str = "rw"
    def to_int = 2
    def to_proc = proc { :rp }
    def only_refined = :only_refined
  end
end

module AliasOps836
  refine String do
    alias_method :label836, :upcase
  end
end

def try836
  yield
rescue => e
  "#{e.class}: #{e.message}"
end

using IntOps836
# the builtins' own + and <=> on Integers
p [1, 2, 3].sum, [1, 2, 3].sum(10), [1, 2, 3].each.sum
p [1, 2, 3].inject(:+), [1, 2, 3].reduce(0, :+), [[1, 2]].map(&:sum)
p try836 { [1, 2].sum { :a } }
p [3, 1, 2].max, [3, 1, 2].min, [3, 1, 2].sort, [3, 1, 2].minmax
p format("%s", 1), sprintf("%s-%s", 1, 2), "%s" % 1
# ...while what this file writes is refined
p 1 + 2, 1 <=> 2, "#{1}", 1.send(:+, 2), 1.public_send(:<=>, 2)
p [1, 2].map { |x| x + 1 }, [1, 2].inject { |a, b| a + b }, [1, 2].map(&:dbl)
p 1.method(:dbl).call, [1].each_with_object([]) { |x, a| a << x + 1 }

xs = [V836.new(2), V836.new(1), V836.new(3)]
using VOps836
# comparison, equality and hashing inside the builtins: the class's own
p xs.sort, xs.max, xs.min, xs.max(2), xs.sort_by { |v| v }, xs.max_by { |v| v }
p xs.include?(V836.new(9)), xs.index(V836.new(9)), xs.count(V836.new(9))
p xs == [V836.new(9)] * 3, xs != [V836.new(9)] * 3, (xs - [V836.new(9)]).size
p xs.uniq.size, (xs & [V836.new(9)]).size, xs.difference([V836.new(9)]).size
p({V836.new(1) => :x}[V836.new(9)], {k: V836.new(1)} == {k: V836.new(9)})
p xs.tally.size, xs.group_by { |v| v }.size, xs.uniq { |v| v }.size
p xs.each_with_object({}) { |v, h| h[v] = 1 }.size, xs.to_h { |v| [v, 1] }.size
p try836 { (V836.new(1)..V836.new(3)).to_a }
p try836 { 1 + V836.new(2) }, try836 { xs.sum(V836.new(0)) }
p xs.join(","), format("%s", xs[0])
# ...and the calls written here are refined
p xs[0] <=> xs[1], xs[0] == xs[1], xs[0].hash, "#{xs[0]}", xs[0] + xs[1]

w = W836.new
using WOps836
# the implicit conversions a builtin or the syntax makes: the class's own
p [*w], [w].flatten, Array(w), String(w), [0].concat(w), [0] + w
p "a" + w, [10, 20, 30][w], [1, 2, 3].first(w), File.join("a", w)
p [{a: 1}.merge(w), [w].map { |a, b| [a, b] }]
def splat836(*a, **k) = [a, k]
p splat836(*w), splat836(**w)
for a, b in [w]; p [a, b]; end
# ...the ones ruby makes with the caller's refinements
p [1].map(&w), w.respond_to?(:only_refined), w.method(:only_refined).call

using AliasOps836
# a refined alias of a builtin answers, directly and as a Method
p 'x'.label836, 'x'.method(:label836).call
