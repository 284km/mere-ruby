h = {}
1500.times { |i| h[i] = i.even? ? nil : false unless h.key?(i) }
p [h.size, h.key?(0), h.has_key?(1), h.include?(1499), h.member?(1500)]
h[0] = :replaced
h.delete(1)
h[1500] = :appended
p [h.key?(0), h.key?(1), h.member?(1500), h.values_at(0, 1, 1500)]
a = [1]
h = {a => :array}
p [h.key?(a), h.key?([1]), h.include?([1, 2])]
a << 2
h.rehash
p [h.key?(a), h.member?([1, 2])]
identity = {}.compare_by_identity
x = "key"
identity[x] = nil
p [identity.key?(x), identity.key?(x.dup)]
class MembershipKey
  attr_reader :n
  def initialize(n); @n = n; end
  def hash; @n % 2; end
  def eql?(other); other.is_a?(MembershipKey) && @n == other.n; end
end
custom = {}
20.times { |i| custom[MembershipKey.new(i)] = i }
p [custom.key?(MembershipKey.new(5)), custom.include?(MembershipKey.new(21))]
GC.start
p custom.member?(MembershipKey.new(19))

# Identity hashes must never structurally digest a shared container graph.
shared = []
22.times { shared = [shared, shared] }
identity = {}.compare_by_identity
identity[shared] = nil
p [identity.key?(shared), identity.has_key?(shared),
   identity.include?(shared), identity.member?(shared)]
p [identity.key?([]), identity.member?(nil)]
