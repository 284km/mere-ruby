# Enumerator::Chain, an Enumerator inspected inside itself, a flip-flop in two
# threads, and a join that waits "forever" (note 447).

a = (1..5).each
e1 = Enumerator::Chain.new(a)
e2 = Enumerator::Chain.new(a, [6, 7, 8])
e5 = Enumerator::Chain.new(e1, e2)
e1.define_singleton_method(:rewind) { 1 }
puts e5.inspect

chain = [1].to_enum + [2].to_enum
p (chain.methods & [:feed, :next, :next_values, :peek, :peek_values])

e4 = (a + [9]).dup
class << e4
  attr_reader :called
  def each
    super
    @called = true
  end
end
p (e4 + [10]).to_a
p e4.called

arr = []
en = arr.each_with_object(arr)
arr << en
puts en.inspect

ff = proc { |n| true if n == 3..n == 5 }
v = 1..9
go = true
th = Thread.new {
  v.select { |i|
    Thread.pass while go
    ff[i].tap { go = true }
  }
}
v1 = v.select { |i|
  Thread.pass until go
  ff[i].tap { go = false }
}
p v1, th.value

p Thread.new { 1 }.join(4611686018427387903).class
