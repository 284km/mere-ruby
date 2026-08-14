# What a method says about its own signature. `parameters` reports the
# declaration in order; whether a name is required or optional is the presence
# of a default, which mere-ruby keeps in a list of its own.
class C
  def m(a, b = 2, *r, c, k:, j: 1, **kk, &blk); end
  def self.sm(x); end
  def none; end
  private def pv(a, b); end
  attr_accessor :attr1
end

p C.instance_method(:m).parameters
p C.new.method(:m).parameters
p C.new.method(:m).unbind.parameters
p C.method(:sm).parameters
p C.new.method(:none).parameters
p C.instance_method(:pv).parameters
p C.new.method(:attr1).parameters
p C.new.method(:attr1=).parameters      # the writer's argument has no name
p C.instance_method(:m).parameters.map(&:first)

def top(a, b = 1, *c, d:, e: 2, **f, &g); end
p method(:top).parameters
def kwrest(**opts); end
p method(:kwrest).parameters
def anon(*); end
p method(:anon).parameters

# arity counts the MANDATORY arguments, negative when a splat or an optional
# argument makes that a lower bound. The keywords contribute one argument
# between them: a required one makes it mandatory, an optional one does not.
def a1(x); end
def a2(x, y:); end
def a3(x, y: 1); end
def a4(x, *r, y:); end
def a5(y:, z:); end
def a6(**k); end
def a7(x, y = 1); end
p [method(:a1).arity, method(:a2).arity, method(:a3).arity, method(:a4).arity,
   method(:a5).arity, method(:a6).arity, method(:a7).arity]
p [C.instance_method(:m).arity, C.new.method(:none).arity, C.method(:sm).arity]

# A proc and a lambda count the same mandatory arguments and differ only in
# whether an optional one relaxes the count -- a lambda checks its arity.
p [->(a, b = 1) {}.arity, ->(a, *r) {}.arity, ->(a, b) {}.arity, ->(*) {}.arity, -> {}.arity]
p [proc { |x| }.arity, proc { |x, y = 1| }.arity, proc {}.arity, proc { |*a| }.arity]
p [proc { |x, k: 1| }.arity, proc { |x, k:| }.arity, proc { |x, **k| }.arity]
p [lambda { |x, k:| }.arity, lambda { |x, **k| }.arity, proc { |x, &b| }.arity]

p ->(a, b = 1) {}.parameters
p proc { |x, y = 1| }.parameters
p proc { |*a, **k, &b| }.parameters
p proc { |x, &b| }.parameters
p :upcase.to_proc.arity
