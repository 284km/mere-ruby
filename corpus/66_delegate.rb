require "delegate"

class Wrapped < SimpleDelegator
  def extra; :extra; end
end
w = Wrapped.new([1, 2, 3])
p w.size, w.first, w.extra
p w.respond_to?(:size), w.respond_to?(:extra), w.respond_to?(:nope)
p w.map { |x| x * 2 }
p w.to_s
w.__setobj__([9])
p w.size, w == [9]

d = SimpleDelegator.new("hi")
p d.upcase, d.length, d.inspect

Q = DelegateClass(Array)
q = Q.new([4, 5])
p q.size, q.last

# `super` inside an overridden respond_to? reaches the builtin one
class Asker
  def known; 1; end
  def respond_to?(m, include_private = false)
    return true if m == :virtual
    super
  end
end
a = Asker.new
p a.respond_to?(:known), a.respond_to?(:virtual), a.respond_to?(:missing)
