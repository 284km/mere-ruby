# Enumerator, Enumerator::Lazy and Enumerator::Chain had no #initialize of
# their own: `allocate` then `send(:initialize, ...)` was "undefined method
# 'initialize'", so the object could never be set up, and none of the three
# listed it as a private instance method. It is one step now, which `.new`
# runs after allocating too. A Proc given as a Lazy's size is asked.
e = Enumerator.allocate
p e.send(:initialize, 3) { |y| y << 1 << 2 }.equal?(e), e.to_a, e.size
p Enumerator.allocate.send(:initialize, -> { 200 }) {}.size
p Enumerator.allocate.send(:initialize, Float::INFINITY) {}.size
p((Enumerator.allocate.send(:initialize) rescue $!))
p((Enumerator.allocate.freeze.send(:initialize) {} rescue $!))
p((Enumerator.new(1, 2) {} rescue $!))
l = Enumerator::Lazy.allocate
l.send(:initialize, [1, 2, 3], 7) { |y, *v| y.<<(*v) }
p l.first(2), l.size
p Enumerator::Lazy.allocate.send(:initialize, [1], -> { 200 }) {}.size
p((Enumerator::Lazy.allocate.send(:initialize, [1]) rescue $!))
p((Enumerator::Lazy.allocate.send(:initialize) {} rescue $!))
p((Enumerator::Lazy.allocate.freeze.send(:initialize, [1]) {} rescue $!))
c = Enumerator::Chain.allocate
p c.send(:initialize, 0..1, 2..3).equal?(c), c.to_a
p((Enumerator::Chain.allocate.freeze.send(:initialize) rescue $!))
p Enumerator.private_instance_methods(false).include?(:initialize),
  Enumerator::Lazy.private_instance_methods(false).include?(:initialize),
  Enumerator::Chain.private_instance_methods(false).include?(:initialize)
