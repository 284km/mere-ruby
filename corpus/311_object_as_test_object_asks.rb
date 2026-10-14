# Object as CRuby's test_object asks it (note 333): a container is no count
# (`[].first([42])` was nil), an ivar name is converted once, a class in a
# message is its own #to_s, a #respond_to? that requires three arguments is
# refused by name, undef_method may name BasicObject's private hooks, and a
# Yielder can be copied.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message}"; end
  puts "#{n}: #{r.gsub(/0x\h+/, '0x')}"
end
P311 = Class.new { define_singleton_method(:to_s) { "Pile" } }
t(1) { Object.new.clone(freeze: P311.new) }
class Cnt311; attr_reader :count; def initialize = @count = 0; def to_str = (@count += 1; "@foo"); end
t(2) { o = Object.new; o.instance_variable_set(:@foo, :foo); n = Cnt311.new; [o.instance_variable_get(n), n.count] }
t(3) { [([].first([42]) rescue $!.message), ([1].take({}) rescue $!.message), ([1, 2].last(1..2) rescue $!.message), [1, 2, 3].first(2.9)] }
p311 = Object.new; class << p311; define_method(:respond_to?) { |a, b, c| false }; end
t(4) { [[p311]].flatten }
t(5) { c = Class.new { def method_missing(*) = :mm }; c.class_eval { undef_method(:method_missing) }; (c.new.foo rescue $!.class) }
t(6) { (Class.new { undef_method(:nope311) } rescue $!.message.sub(/#<Class:[^>]*>/, "C")) }
t(7) { y = Enumerator::Yielder.new { |x| x }; [y.dup.class, y.dup.equal?(y)] }
