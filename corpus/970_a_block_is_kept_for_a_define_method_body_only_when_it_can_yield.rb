# define_method / define_singleton_method with a receiver, and the blocks of
# Class.new / Module.new / Struct.new, keep the block of the method they are
# called in ONLY for a body that can reach it: a `yield`, also inside a
# nested block or a lambda. Every body kept it, and through it the calling
# method's frame, for as long as the defined method lived -- Rails defines
# thousands of methods that way, and activerecord's nested_attributes_test
# went from 1.0 GB to the 2 GiB limit. What a body can still ask without the
# block being kept: `block_given?` and `defined?(yield)` answer for the frame
# it was written in.
def t(label)
  r = begin; yield; rescue LocalJumpError => e; [:lje, e.message]; rescue ArgumentError => e; [:arg, e.message]; end
  p [label, r]
end
# receiver forms, the defining method called with a block and without
def r_plain(k) = k.define_method(:go) { yield 1 }
def r_nested(k) = k.define_method(:go) { [1, 2].map { |v| yield v } }
def r_lambda(k) = k.define_method(:go) { -> { yield 9 }.call }
def r_given(k) = k.define_method(:go) { block_given? }
def r_bind(k) = k.define_method(:go) { binding.eval("block_given?") }
def r_defined(k) = k.define_method(:go) { defined?(yield) }
def r_procnew(k) = k.define_method(:go) { Proc.new }
def r_none(k) = k.define_method(:go) { :no_yield }
%i[r_plain r_nested r_lambda r_given r_bind r_defined r_procnew r_none].each do |m|
  k = Class.new; send(m, k) { |v| v * 10 }; t([m, :with]) { k.new.go }
  k = Class.new; send(m, k);                 t([m, :without]) { k.new.go }
end
def s_plain(o) = o.define_singleton_method(:go) { yield 2 }
def s_nested(o) = o.define_singleton_method(:go) { [3].map { |v| yield v } }
def s_given(o) = o.define_singleton_method(:go) { block_given? }
def s_none(o) = o.define_singleton_method(:go) { :no_yield }
%i[s_plain s_nested s_given s_none].each do |m|
  o = Object.new; send(m, o) { |v| v * 10 }; t([m, :with]) { o.go }
  o = Object.new; send(m, o);                 t([m, :without]) { o.go }
end
# the block forms
def m_nested = Module.new { define_method(:go) { [1, 2].map { |v| yield v } } }
def m_given = Module.new { define_method(:go) { block_given? } }
def m_none = Module.new { define_method(:go) { :no_yield } }
def c_given = Class.new { define_method(:go) { block_given? } }
def c_lambda = Class.new { define_method(:go) { -> { yield 6 }.call } }
def st_nested = Struct.new(:a) { define_method(:go) { [a].map { |v| yield v } } }
t([:m_nested, :with]) { Object.new.extend(m_nested { |v| v * 10 }).go }
t([:m_nested, :without]) { Object.new.extend(m_nested).go }
t([:m_given, :with]) { Object.new.extend(m_given { }).go }
t([:m_given, :without]) { Object.new.extend(m_given).go }
t([:m_none, :with]) { Object.new.extend(m_none { }).go }
t([:c_given, :with]) { c_given { }.new.go }
t([:c_lambda, :with]) { c_lambda { |v| v * 10 }.new.go }
t([:st_nested, :with]) { st_nested { |v| v * 10 }.new(4).go }

# the same name defined again, first from a call with a block and then
# from one without: the second body has no block to yield to
k = Class.new
r_plain(k) { |v| v * 10 }
t([:redefined, :first]) { k.new.go }
r_plain(k)
t([:redefined, :second]) { k.new.go }
# many methods defined under one block still answer, each through its own
k = Class.new
def many(k, n) = n.times { |i| k.define_method(:"m#{i}") { yield i } }
many(k, 50) { |v| v + 100 }
p (0...50).map { |i| k.new.send(:"m#{i}") }.sum
