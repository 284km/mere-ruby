# Refinements as ruby has them (note 439).

# a refinement sits in front of the modules prepended to its class, and its
# super goes through them
module PrepM1; def foo = super << :m1; end
class PrepC; prepend PrepM1; def foo = [:c]; end
module PrepM2; refine PrepC do; def foo = super << :m2; end; end

# super from a refinement of a subclass reaches the parent's refinement
class RParent; end
class RChild < RParent; end
module RSuper
  refine RParent do
    def to_s = "Parent"
  end
  refine RChild do
    def to_s = super + " -> Child"
  end
end

# a refined method calls its refinement's other methods, by a bare name too
class RA; def foo = "o"; end
module RAB
  BAR = "bar"
  def bar = "#{foo}:#{BAR}"
end
module RAC
  refine RA do
    import_methods RAB
    def foo = "r"
    def baz = [foo, self.foo]
  end
end

# a refined raise is what `raise` calls
module RRaise
  refine Object do
    def raise(*) = :refined_raise
  end
end

using PrepM2
using RSuper
using RAC
p PrepC.new.foo
p RChild.new.to_s
p RA.new.bar, RA.new.baz

module UsesRaise
  using RRaise
  def self.m = raise
end
p UsesRaise.m
p UsesRaise.dup.m

# using in a block at the top level stays for the file after it
module RS
  refine String do
    def to_s = :R
  end
end
2.times { |i|
  p ''.to_s
  using RS if i == 0
  p ''.to_s
}

# an eval given a binding keeps the using
module RUp
  refine String do
    def upcase = reverse
  end
end
b = binding
puts eval(%{using RUp; "abc".upcase}, b)
puts eval(%{"abc".upcase}, b)

# &obj asks method_missing for to_proc
class MMProc
  def method_missing(*) = proc { "method_missing" }
  def run = yield_it(&self)
  def yield_it(&b) = b.call
end
p MMProc.new.run
