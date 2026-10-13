# Method and UnboundMethod as CRuby's test_method asks them (note 323):
# define_method refuses a body that is not callable, and a missing one; an
# inspect writes anonymous `*`, `**`, `&` the way ruby's method_inspect does;
# a builtin's owner is where ruby defines it (Kernel), with nothing above it;
# bind_call hands its block on; a Method's clone keeps its singleton methods;
# public_methods(false) sees the modules an object was extended with; and
# __dir__ inside an eval is the directory of the file the eval named.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message.gsub(/0x\h+/, '0x')}"; end
  puts "#{n}: #{r}"
end
t(1) { [(Class.new.class_eval { define_method(:f, Object.new) } rescue $!.message), (Class.new.class_eval { define_method(:f, :f) } rescue $!.message), (Class.new.class_eval { define_method(:f) } rescue $!.message), (Class.new.class_eval { define_method } rescue $!.class)] }
class TM; def a(*, **); end; def b(...); end; def c(x, *, k: 1, &); end; def d(**nil); end; def e(p, q = 1, *r, s, k:, &blk); end; end
t(2) { %i[a b c d e].map { TM.instance_method(_1).inspect[/\(.*\)/] } }
t(3) { [Object.instance_method(:tap).owner, Object.instance_method(:tap).super_method, Class.new.instance_method(:then).owner, String.instance_method(:to_s).super_method] }
class BC; def m(a = 0) = yield + a; end
t(4) { [BC.instance_method(:m).bind_call(BC.new, 1) { 2 }, Object.instance_method(:tap).bind_call(5) { }] }
t(5) { o = Object.new; def o.foo = :foo; m = o.method(:foo); def m.bar = :bar; [m.clone.call, m.clone.bar, (m.dup.bar rescue $!.class)] }
t(6) { m = Module.new { def m1; end }; a = Class.new { def a; end }; obj = a.new; obj.extend(m); obj.public_methods(false).sort }
t(7) { [eval("__dir__", binding, "arbitrary/file.rb"), Object.new.instance_eval("__dir__", "arbitrary/file.rb"), eval("__dir__"), __dir__ == File.dirname(File.realpath(__FILE__))] }
