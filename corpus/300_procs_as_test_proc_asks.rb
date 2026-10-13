# Proc as CRuby's test_proc asks it (note 322): a Method's proc reports the
# method's parameters, Kernel's builtins their arity, a proc with keyword
# parameters still spreads one Array, a composition with a Method or a
# callable is a lambda, a curried or composed proc works as a block and has
# no binding, a curried collection warns of a block it drops, procs hash
# apart (and a dup with its original), a clone keeps singleton methods,
# define_singleton_method takes a body on main and on an object, a
# prepended or refined #call reaches the builtin through super, and `_5 and
# x` / `it or x` name implicit parameters.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message.gsub(/0x\h+/, '0x')}"; end
  puts "#{n}: #{r}"
end
def pm1(a, b = 2); end
t(1) { [method(:pm1).to_proc.parameters, method(:putc).arity, method(:proc).arity, method(:putc).parameters, method(:puts).parameters] }
t(2) { [proc { |c, b, a: 1| [c, b, a] }.call([1, 2]), proc { |c, b, a: 1| [c, b, a] }.call([1, 2], a: 5), proc { |c, a: 1| [c, a] }.call([1, 2])] }
t(3) { f = proc { _1 }; c = Object.new; def c.call(x) = x; [(f << c).lambda?, (f >> c).lambda?, (f << method(:pm1)).lambda?] }
t(4) { b = ->(x, y) { x + y }.curry; c = proc { |x| x * 2 } >> proc { |x| x + 1 }; [[1, 2].map(&b[10]), [1, 2].map(&c), instance_exec(2, &b[1]), (b.binding rescue $!.message)] }
t(5) { o = Object.new; def o.foo(a, b = 42); end; (o.method(:foo).to_proc.curry(3) rescue $!.message) }
t(6) { ps = Array.new(20) { proc { :x } }; x = proc { }; [ps.map(&:hash).uniq.size, x.hash == x.dup.hash, :a.to_proc.hash == :a.to_proc.hash] }
t(7) { b = proc { |x| x }; def b.foo = :sfoo; [(b.dup.foo rescue $!.class), b.clone.foo] }
define_singleton_method(:dsm1) { :dsm1 }
define_singleton_method(:dsm2, ->(x) { x * 2 })
t(8) { [dsm1, dsm2(4), (Object.new.dsm1 rescue $!.class)] }
class Dsm; def hi = [:hi, self.class]; def m(pr) = define_singleton_method(:g, pr); end
t(9) { o = Dsm.new; o.m(proc { :g }); d = Dsm.new; d.define_singleton_method(:h, Dsm.new.method(:hi)); [o.g, d.h, d.singleton_methods] }
t(10) { Proc.prepend(Module.new { def call(*) = [:pre, super] }); proc { :body }.call }
t(11) { ["foo".tap { _5 and 1; break binding.implicit_parameters }, "foo".tap { it or 1; break binding.implicit_parameters }, proc { _3 or 1 }.arity] }
