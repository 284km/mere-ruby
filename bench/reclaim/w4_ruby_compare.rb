# the same work in both interpreters, so the live set is the same and the
# difference is what is never given back
class Node
  def initialize(v, nxt); @v = v; @nxt = nxt; end
  def sum; @v + (@nxt ? @nxt.sum : 0); end
end
head = nil
1000.times { |i| head = Node.new(i, head) }
acc = 0
2000.times { acc += head.sum }
p acc
