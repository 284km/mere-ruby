# with_index's offset converts: a Float truncates, #to_int is asked, nil is none
e = [1, 2, 3].each
o = Object.new
def o.to_int = 1
p e.with_index(1.7).to_a, e.with_index(o).to_a, e.with_index(nil).to_a
begin; e.with_index("1") { }; rescue TypeError => x; p x.class; end

# Enumerator::Chain#rewind rewinds what the walk reached, last first
class Src
  def initialize(log, name) = (@log = log; @name = name)
  def each = yield(@name)
  def rewind = @log << @name
end
log = []
c = Enumerator::Chain.new(Src.new(log, :a), Src.new(log, :b))
p c.rewind.equal?(c), log
c.each { }
c.rewind
p log

# Set.new walks with #each_entry when there is one
class Pairs
  include Enumerable
  def each = (yield 1, 2; yield 3, 4)
end
p Set.new(Pairs.new).to_a

# Random: equal when seeded alike AND at the same place; random_number never refuses
a = Random.new(42)
b = Random.new(42)
p a == b
a.rand
p a == b
b.rand
p a == b
p Random.new(42) == Random.new(42.5)
p [Random.random_number.class, Random.new(1).random_number(0).class, Random.new(1).random_number(10).class]
p Random.new(2 ** 252).bytes(2).bytes, Random.new(2 ** 252).seed == 2 ** 252
p Random.bytes(5).size, Random.bytes(5).encoding
