# Enumerator#first and #take take no block. One given to them is not called,
# and the walk still stops at the count:
#
#   enum = Post.find_in_batches(batch_size: 1)
#   assert_queries_count(4) { enum.first(4) do |batch| ... end }
#
# With a block the call went to the iterator path and ran the enumerator to
# its end -- 12 queries for 4 batches.
$n = 0
def each_b
  return to_enum(:each_b) unless block_given?
  10.times { |i| $n += 1; yield [i] }
end
en = each_b
called = []
p en.first(4) { |b| called << b }, $n, called
$n = 0
p en.first(4), $n
$n = 0
p en.first { |b| called << b }, $n, called
$n = 0
p en.take(3) { |b| called << b }, $n, called
$n = 0
p en.first(0) { }, $n
$n = 0
e2 = Enumerator.new { |y| 10.times { |i| $n += 1; y << i } }
p e2.first(2) { }, $n
$n = 0
r = en.first(2) do |b|
  called << b
end
p r, $n, called
# an Array's and a Range's are as they were
p [1, 2, 3].first(2) { }, (1..10).first(3) { }, [1, 2, 3].take(1) { }
