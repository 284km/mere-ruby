# A qualified constant inside a class that was made by assignment (`S =
# Struct.new(...)`, `D = Class.new`) and then reopened reads its head
# lexically, as a bare name does: rspec-core's SummaryNotification reaches
# `Formatters::Helpers` this way, and it was a NameError
module Outer; module Inner; module Fmt; module H; def self.x = :h; end; end; end; end
module Outer::Inner
  module N
    S = Struct.new(:a)
    class S
      def f = Fmt::H.x
      def g = Fmt
      def miss = Fmt::Nope
    end
    D = Class.new
    class D
      def f = Fmt::H.x
    end
    class C
      def f = Fmt::H.x
    end
  end
end
p Outer::Inner::N::S.new(1).f
p Outer::Inner::N::S.new(1).g
p Outer::Inner::N::D.new.f
p Outer::Inner::N::C.new.f
begin
  Outer::Inner::N::S.new(1).miss
rescue NameError => e
  p [e.message, e.name]
end
