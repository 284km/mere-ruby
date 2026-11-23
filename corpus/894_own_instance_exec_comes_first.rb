# An object's OWN #instance_exec / #instance_eval answers a call with a
# block: rspec-core's Example#instance_exec hands the block to the example
# group instance, and every before hook ran with the Example as self instead
class Target; end
class Proxy
  def initialize(t) = @t = t
  def instance_exec(*args, &block) = @t.instance_exec(*args, &block)
end
pr = Proxy.new(Target.new)
pr.instance_exec(1) { |x| p [self.class, x] }
blk = proc { |x| p [self.class, x] }
pr.instance_exec(2, &blk)
pr.send(:instance_exec, 3, &blk)
class OwnEval
  def instance_eval(*) = :own
end
p OwnEval.new.instance_eval { 1 }
# ...and the builtin is still the builtin for everything else, and for a
# Method taken of it before the override
saved = Object.instance_method(:instance_exec)
p saved.bind(pr).call(4) { |x| [self.class, x] }
o = Object.new
p o.instance_exec(5) { |x| [self.equal?(o), x] }
