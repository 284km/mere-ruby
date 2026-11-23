# In a class made by assignment and reopened (corpus 895), `defined?` of a
# qualified constant reads its head lexically as the read does, and a
# missing tail asks the head's const_missing (review of #178)
module Outer
  module Inner
    module Fmt
      module H; end
      def self.const_missing(n) = [:cm, n]
    end
  end
end
module Outer::Inner
  module N
    S = Struct.new(:a)
    class S
      def d = defined?(Fmt::H)
      def d2 = defined?(Fmt::Nope)
      def d3 = defined?(Fmt)
      def d4 = defined?(Nowhere::H)
      def miss = Fmt::Nope
    end
  end
end
s = Outer::Inner::N::S.new(1)
p s.d, s.d2, s.d3, s.d4, s.miss
