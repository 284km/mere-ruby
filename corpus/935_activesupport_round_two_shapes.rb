# The next ActiveSupport shapes, each without Rails.

def try
  yield
rescue => e
  "#{e.class}: #{e.message}"
end

# 1. a Ruby method whose name ends in "!" is not a builtin mutator: called with
#    a block on a frozen value it runs (ActiveSupport's Object#try!)
module Trying
  def try!(*args, &block)
    if args.empty? && block_given?
      block.arity == 0 ? instance_eval(&block) : yield(self)
    else
      public_send(*args, &block)
    end
  end
end
Object.include Trying
frozen = "Hello".freeze
p try { frozen.try!(&:reverse) }, try { frozen.try! { reverse } }, try { frozen.try!(:upcase) }
p try { {}.freeze.try! { size } }, try { [].freeze.try! { size } }
class String
  def shout!(&b) = b ? b.call(upcase) : upcase
end
p try { frozen.shout! { |s| s + "!" } }
p try { frozen.upcase! { } }

# 2. a Struct class's dup is a Struct class (ActiveSupport's deep_mergeable_test)
Wrapper = Struct.new(:underlying) do
  class << self
    remove_method :[]
    def [](value) = value.is_a?(Hash) ? new(value.transform_values { |v| self[v] }) : value
  end
end
OtherWrapper = Wrapper.dup
p OtherWrapper[{ a: { b: 1 } }]
p OtherWrapper.new(1), OtherWrapper.members, OtherWrapper.new(2).to_a, OtherWrapper.new(3) == OtherWrapper.new(3)

# 3. a Range method that replaces Enumerable's reaches it through super
#    (ActiveSupport's Range#sum)
class Range
  def sum(initial = 0)
    if block_given? || !(first.is_a?(Integer) && last.is_a?(Integer))
      super
    else
      [:fast, initial]
    end
  end
end
p (1..4).sum, try { (1..4).sum { |x| x * 2 } }, try { ("a".."c").sum("") }, try { (1.5..3.5).sum }

# 4. a Struct has no #to_ary: it is not destructured or flattened, and
#    Array.wrap(struct) is [struct]
Point = Struct.new(:x, :y)
pt = Point.new(1, 2)
p pt.respond_to?(:to_ary), [pt].flatten.size
a, b = pt
p a, b
[[pt]].each { |(q)| p q }
def wrap(o) = o.nil? ? [] : (o.respond_to?(:to_ary) ? (o.to_ary || [o]) : [o])
p wrap(pt)

# 5. a Symbol alias of a builtin takes all its arguments
class Symbol
  alias :starts_with? :start_with?
  alias :ends_with? :end_with?
end
s = :hello
p s.starts_with?("hel"), s.starts_with?("el"), s.starts_with?("he", "lo"), s.starts_with?("el", "lo")
p s.ends_with?("o"), s.ends_with?("el"), s.ends_with?("he", "lo"), s.ends_with?("he", "ll")

# 6. `module X` / `class X` on a constant that names another class or module
#    reopens that one (nokogiri's html.rb: `HTML = Nokogiri::HTML4; module
#    HTML`), and the other kind is refused
module H4; def self.h = :h4; end
H = H4
p try { module H; class D; end; def self.x = :x; end }, H4::D, H4.x, H::D.name
module NN
  module M4; end
  M = NN::M4
  module M; class E; end; end
end
p NN::M4::E, NN::M::E.name
class K4; end
K = K4
p try { class K; def z = 2; end }, K4.new.z
p try { module K; end }.lines.first.chomp
p try { class H; end }.lines.first.chomp
X = Comparable
p try { module X; def cmpx = 1; end }, Comparable.instance_method(:cmpx).owner
S = String
p try { class S; def ss = 3; end }, "a".ss
