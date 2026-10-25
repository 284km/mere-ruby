# Where a block and a lambda begin, a lambda's arity error at its own line,
# method_missing for builtin receivers, a binding asked of a C caller, a
# refined &:sym that is a lambda, and main's define_method with a method

def bl(*a, &b) = b.source_location[1]
r = bl(1,
       2) do
end
p r
l = ->(x,
       y) {
}
p l.source_location[1], (lambda do end).source_location[1]
f = lambda do
  true
end
begin
  3.times(&f)
rescue ArgumentError => e
  p e.backtrace.first[/:(\d+):/, 1].to_i
end

class Integer
  def method_missing(m, *a) = m == :twice ? self * 2 : super
  def respond_to_missing?(m, p = false) = m == :twice || super
end
p 21.twice, 1.respond_to?(:twice), (1.nope rescue $!.class)

p((method(:binding).call rescue [$!.class, $!.message]))
p binding.class

class R397; end
module Ref397
  refine R397 do
    def hoge = :hoge
  end
end
using Ref397
def take(&b) = b
p take(&:hoge).lambda?, take(&:hoge).call(R397.new)

define_method(:dm397) { 397 }
self.instance_eval { define_method(:dm397b, Object.instance_method(:dm397)) }
p dm397b
