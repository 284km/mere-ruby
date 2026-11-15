require 'api_fixture'
$count = 0
def check(value)
  raise 'api contract failed' unless value
  $count += 1
end
def raises(kind)
  yield
rescue kind => e
  $count += 1
  e
else
  raise "expected #{kind}"
end
A = ApiFixture

# What C writes through a pointer it took before its Fiber was stopped goes
# back to the object -- also when another stack ran a C call of its own
# meanwhile.
s = +'abc'
f = Fiber.new { A.ptr_after_yield(s) { Fiber.yield } }
f.resume
A.noop
f.resume
check(s == 'Xbc')
a = [1, 2]
f = Fiber.new { A.ary_ptr_after_yield(a) { Fiber.yield } }
f.resume
A.noop
GC.start
f.resume
check(a == [99, 2])
# (...and without a call between: the control)
s = +'abc'
f = Fiber.new { A.ptr_after_yield(s) { Fiber.yield } }
f.resume
f.resume
check(s == 'Xbc')

# A primitive is ruby's operation, not the method a subclass (or the object's
# singleton) defined under its name.
class OverArray < Array
  def push(*) = :intercepted
end
class OverString < String
  def <<(other) = :intercepted
  def length = 999
  def freeze = :intercepted
end
class OverHash < Hash
  def []=(key, value)
    :intercepted
  end
end
class OverObject
  def freeze = :intercepted
  def is_a?(klass) = true
  def kind_of?(klass) = true
end
oa = OverArray.new
A.push(oa, 7)
check(oa.to_a == [7])
os = OverString.new('ab')
A.append(os, 'c')
check(os.to_s == 'abc')
check(A.length(os) == 3)
A.freeze(os)
check(os.frozen?)
oh = OverHash.new
A.aset(oh, :k, 1)
check(oh.fetch(:k) == 1)
oo = OverObject.new
A.freeze(oo)
check(oo.frozen?)
check(A.kind_of(oo, String) == false)
single = [1]
def single.push(*) = :intercepted
A.push(single, 2)
check(single == [1, 2])
plain = []
A.push(plain, 1)
check(plain == [1])

# rb_get_kwargs takes what it found out of the Hash when it is given a place
# for the values -- whether or not other keywords may stay -- and only looks
# when it is not.
h = { a: 1, b: 2, x: 3 }
check(A.kwargs(h, 1, -2, true) == [2, 1, 2])
check(h == { x: 3 })
h = { a: 1, b: 2 }
check(A.kwargs(h, 1, 1, false) == [2, nil, nil])
check(h == { a: 1, b: 2 })
h = { a: 1 }
check(A.kwargs(h, 1, 1, true) == [1, 1, :undef])
check(h == {})
check(A.kwargs(nil, 0, 2, true) == [0, :undef, :undef])
check(raises(ArgumentError) { A.kwargs({ b: 1 }, 1, 1, true) }.message == 'missing keyword: :a')
check(raises(ArgumentError) { A.kwargs({ a: 1, z: 2, y: 3 }, 1, 1, true) }.message == 'unknown keywords: :z, :y')

# A class C defined -- under a module C defined under a module C defined --
# is the class that name finds: Ruby code subclasses it and reopens it.
class Custom < ApiFixture::Mid::Base
end
check(Custom.superclass.equal?(ApiFixture::Mid::Base))
check(Custom <= ApiFixture::Mid::Base)
check(Custom.new.is_a?(ApiFixture::Mid::Base))
check(A.kind_of(Custom.new, ApiFixture::Mid::Base) == true)
check(ApiFixture::Mid::Leaf.superclass.equal?(ApiFixture::Mid::Base))
check(ApiFixture::Mid::Base.name == 'ApiFixture::Mid::Base')
module ApiFixture
  module Mid
    class Base
      def extra = :reopened
    end
  end
end
check(ApiFixture::Mid::Leaf.new.extra == :reopened)
check(Custom.new.extra == :reopened)

# rb_proc_new makes a Proc, not a lambda.
pr = A.new_proc
check(pr.lambda? == false)
check(pr.call(5, 6) == [5, 2, :data])
check([[1, 2]].map(&pr) == [[[1, 2], 1, :data]])
puts "api contracts: #{$count} passed"
