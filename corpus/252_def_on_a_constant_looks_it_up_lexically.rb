# `def C.m` names C the way any constant reference does: from the innermost
# lexical scope outwards. Inside `class A; class C` that is A::C -- asked at
# the top level only, the method went nowhere reachable. resolv.rb
# (`def Config.default_config_hash`) and net/http (`def HTTP.version_1_1?`)
# are both written this way.
class A
  class C
    def C.f = :f
    def C.g(x = 1) = x
  end
end
p A::C.f
p A::C.g(2)

module Net
  class HTTP
    def HTTP.version_1_1? = false
    class << HTTP
      alias is_version_1_1? version_1_1?
    end
  end
end
p Net::HTTP.is_version_1_1?

# a receiver that is not nested resolves to the outer one
class Top; end
class Other
  def Top.t = :top
end
p Top.t
p Other.respond_to?(:t)

# and from a method body, too
module Outer
  class Inner; end
  def self.setup
    def Inner.made = :made
  end
end
Outer.setup
p Outer::Inner.made
