# Kernel#then, #yield_self and #tap with a block are Kernel's methods: a
# class's own method of the name answers first. The block form ran Kernel's
# whatever the class defined, so the block got the receiver itself.
# activerecord's FutureResult::Complete#then hands its @result on, and
# FutureResult#then makes a Promise: `result.then { |r| r.cast_values }`
# got the wrapper, "undefined method 'cast_values' for an instance of
# ActiveRecord::FutureResult::SelectAll".
class Res; include Enumerable; def each = yield(1); def cast = :cast; end
class Wrap
  def initialize(v) = (@v = v)
  def value = @v
end
class Complete
  def initialize(result) = (@result = result)
  def then(&block) = Wrap.new(@result.then(&block))
end
c = Complete.new(Res.new)
p c.then { |r| r.class }.value, c.then { |r| r.cast }.value

class Fut
  def initialize(r) = (@r = r)
  def result = @r
  def then(&block) = Prom.new(self, block)
end
class Prom
  def initialize(f, b) = (@f = f; @b = b)
  def value = @b.call(@f.result)
  def then(&block) = Prom.new(@f, @b >> block)
end
p Fut.new(Res.new).then { |r| r.cast }.value
p Fut.new(Res.new).then { |r| r }.then { |r| r.cast }.value

# tap and yield_self, a singleton method, a class's own (def self.then)
class T2; def tap = (yield :mine; :ret); def yield_self(&b) = [:ys, b.call(2)]; end
p T2.new.tap { |x| p x }, T2.new.yield_self { |x| x * 2 }
o = Object.new
def o.then = yield(:sng)
p o.then { |x| x }
class CT; def self.then = yield(:cls); end
p CT.then { |x| x }
module M9; def self.tap = yield(:mod); end
p M9.tap { |x| x }, M9.then { |m| m }

# a class whose INSTANCES have #then is itself an object with Kernel's
class Inst; def then = yield(:inst); end
p Inst.then { |k| k }, Inst.new.then { |x| x }

# Kernel's own, as ever
r = Res.new
p r.then { |x| x.equal?(r) }, r.yield_self { |x| x.class }, 5.then { _1 + 1 }
p [1, 2].then { |a| a.sum }, "s".then { _1 + "!" }, nil.then { 1 }, Class.new.then { |k| k.class }
p 3.tap { |x| x + 1 }, [1].tap { |a| a << 2 }
