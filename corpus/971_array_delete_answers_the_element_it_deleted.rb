# Array#delete answers the last ELEMENT it deleted, not its argument:
# rb_ary_delete keeps the element each `e == item` matched. The two are
# different objects whenever == is not identity. activerecord's
# merge_target_lists does `mem_record = memory.delete(record)` to find the
# in-memory record, with its unsaved changes, that a freshly loaded one
# stands for -- and got the loaded one back, so the changes were lost.
class R
  attr_reader :id, :tag
  def initialize(id, tag) = (@id = id; @tag = tag)
  def ==(o) = o.is_a?(R) && o.id == id
  alias eql? ==
  def hash = id.hash
end
mem = [R.new(1, :memory), R.new(2, :memory2), R.new(1, :memory_last)]
got = mem.delete(R.new(1, :argument))
p got.tag, mem.map(&:tag)
p [R.new(3, :in_array)].delete(R.new(3, :arg)) { :not_found }.tag
p [].delete(R.new(9, :arg)), [].delete(1) { |x| [:blk, x] }
s = ["a".dup]
k = "a".dup
p s.delete(k).equal?(k)
p [1.0, 1].delete(1).class, [1, 1.0].delete(1.0).class
h = [R.new(5, :first)]
p h.delete_if { |x| x == R.new(5, :z) }.size, [R.new(6, :e)].reject { |x| x == R.new(6, :q) }.size
p ([R.new(7, :a)] - [R.new(7, :b)]).size, [R.new(8, :a), R.new(8, :b)].uniq.map(&:tag), ([R.new(1, :l)] & [R.new(1, :r)]).map(&:tag), ([R.new(1, :l)] | [R.new(1, :r)]).map(&:tag)
p [R.new(1, :x)].index(R.new(1, :y)), [R.new(1, :x)].include?(R.new(1, :y)), [R.new(1, :x)].find { |e| e == R.new(1, :y) }.tag
# == runs once per element, element == argument
class Cnt
  attr_reader :n
  def initialize(n) = (@n = n)
  def ==(o) = (($calls ||= []) << [n, o.class]; o.is_a?(Integer) ? n == o : (o.is_a?(Cnt) && n == o.n))
end
a = [Cnt.new(1), Cnt.new(2), Cnt.new(1)]
r = a.delete(1)
p r.equal?(1) || r.class, a.size, $calls
$calls = []
p a.delete(9), a.delete(9) { |x| [:none, x] }, $calls.size
# an Array of plain values: the element, not the argument
p [1.0, 1].delete(1.0).class, [2, 2.0].delete(2).class, ["a", :b].delete(:b), [nil, false].delete(nil), [[1], [1]].delete([1])
f = ["k".freeze].freeze
p((f.delete("k") rescue $!.class), (f.dup.delete("zz")))
