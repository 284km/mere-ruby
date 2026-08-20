# A module already in the ancestor chain is NOT put in again: ruby keeps the
# position it already had. Without that, the same module sat in the chain twice
# and `super` from the first occurrence found the SECOND -- an infinite
# recursion. thor's `method_added` calls `super(meth)` on its first line and
# every Thor subclass extends the module its parent already extends, so `bundle`
# recursed until the depth guard caught it, 15000 frames in.
module M1; end
class A1; include M1; end
class B1 < A1; include M1; end
p B1.ancestors
p A1.ancestors

module M2; end
module M3; include M2; end
class C1; include M3; include M2; end
p C1.ancestors

# the same through `extend`, which is the shape thor uses
module Hook
  def method_added(meth)
    super(meth)
    @seen = (@seen || 0) + 1
  end
  def seen; @seen; end
end
class P1; extend Hook; end
class Q1 < P1
  extend Hook
  def one; end
  def two; end
end
p [Q1.seen, P1.seen]
p Q1.singleton_class.ancestors.count { |m| m == Hook }

# ... and a module included twice in the SAME class is still there once
class R1
  include M1
  include M1
end
p R1.ancestors
p R1.include?(M1)

# prepend keeps its own position, ahead of the class
module Pre; end
class S1
  prepend Pre
  include M1
end
p S1.ancestors

# Kernel names itself, where routing `to_s` to the module FUNCTION answered
# "main" (which is right for `Kernel.puts` and wrong for describing the module)
p [Kernel.to_s, Kernel.inspect, Kernel.name, Comparable.to_s]
p Object.ancestors.map(&:to_s)

# `arr * "sep"` is join, not repetition -- ruby's Array#* takes either
p [[1, 2] * ",", [1, 2] * 2, [] * "-", ["a", "b"] * ""]
p [[1, [2, 3]] * ", "]
