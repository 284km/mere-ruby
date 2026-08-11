# A constant bound to a module IS that module's namespace: `A = Inner` makes
# `A::P` mean `Inner::P`. Looking the name up literally finds nothing, which
# is how `uri/common.rb` (REGEXP = RFC2396_REGEXP; REGEXP::PATTERN) failed.
module M
  module Inner
    P = 1
    Q = { a: 2 }
    module Deeper
      R = 3
    end
    def self.hi = :hi
  end
  A = Inner
end

p M::A::P
p M::A::Q
p M::A::Deeper::R
p M::A.hi

B = M::Inner
p B::P
p B::Deeper::R

C = B
p C::Deeper::R

# the alias is a binding, not a rename: the original name still works, and
# the alias tracks later additions to the module
module M
  module Inner
    S = 4
  end
end
p M::Inner::S
p M::A::S
p M::A.equal?(M::Inner)

# a non-module constant must not be treated as a namespace
module M
  N = 5
end
begin
  M::N::P
rescue TypeError, NameError => e
  puts e.class
end
