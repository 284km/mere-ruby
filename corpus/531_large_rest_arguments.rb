def collect_rest(*rest)
  rest
end

[0, 1, 4095, 4096, 5000].each do |n|
  source = Array.new(n) { |i| [i] }
  result = collect_rest(*source)
  raise 'fresh rest array' if source.equal?(result)
  raise 'rest length' unless result.size == n
  GC.start
  source.each_with_index { |v, i| raise 'element identity' unless result[i].equal?(v) }
  result << :tail
  raise 'source mutated' unless source.size == n
  raise 'queue mutation' unless result.pop == :tail && result.size == n
end

class RestParent
  def capture(*args)
    args
  end
end
class RestChild < RestParent
  def capture(*rest)
    rest[0] = :changed
    GC.start
    super
  end
end
result = RestChild.new.capture(*(1..5000))
raise 'super forwarding' unless result.size == 5000 && result.first == :changed && result.last == 5000

def rest_middle(a, b = 2, *middle, z)
  GC.start
  [a, b, middle, z]
end
a, b, middle, z = rest_middle(*(1..5000))
raise 'post arguments' unless [a, b, z, middle.size, middle.first, middle.last] == [1, 2, 5000, 4997, 3, 4999]

def rest_and_keywords(*rest, **keywords)
  GC.start
  [rest, keywords]
end
result, kw = rest_and_keywords(*(1..5000), answer: 42)
raise 'keywords' unless result.size == 5000 && kw == {answer: 42}
hash = {x: 1}
raise 'positional hash' unless collect_rest(1, hash).last.equal?(hash)
raise 'range order' unless [*(-3..2)] == [-3, -2, -1, 0, 1, 2] && [*(2...2)].empty?
raise 'lower endpoint' unless [*(-(2**62)..-(2**62))] == [-(2**62)]
puts 'large rest arguments: ownership, order, GC, mutation and forwarding preserved'
