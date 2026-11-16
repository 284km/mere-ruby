seen = []
source = Enumerator.new do |output|
  [1, 1, 2, 3, 3].each { |value| seen << value; output << value }
end
groups = [0].chain(source).chunk_while { |a, b| a == b }
p [groups.class, groups.size, seen]
p groups.take(2)
p seen
p [1, 1].chain([2, 3, 3]).chunk_while { |a, b| a == b }.to_a
p [].chain((1..)).chunk_while { |a, b| false }.take(3)
p [1, 1].chain([2, 3, 3]).slice_when { |a, b| a != b }.to_a

multiple = Enumerator.new do |output|
  output.yield(1, 2)
  output.yield(1, 2)
  output.yield(3, 4)
end
p [].chain(multiple).chunk_while { |a, b| a == b }.to_a
p [].chain([]).chunk_while { |a, b| true }.to_a
p [1, 1].chain([2]).class.ancestors
p [1].chain([2]).method(:chunk_while).owner
begin
  [].chain([]).chunk_while
rescue => error
  p [error.class, error.message]
end
begin
  [].chain([]).slice_when(:unexpected) { true }
rescue => error
  p [error.class, error.message]
end
