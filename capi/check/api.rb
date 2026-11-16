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

# A block function C passed is told whether it was yielded keywords, and
# rb_yield_block hands them to the C method's block as keywords.
class Yielder
  def keywords = yield(a: 1)
  def hash = yield({ a: 1 })
  def both = yield(1, b: 2)
end
y = Yielder.new
check(A.block_keywords(y, :keywords) == [1, true])
check(A.block_keywords(y, :hash) == [1, false])
check(A.block_keywords(y, :both) == [2, true])
check(A.yield_through(y, :keywords) { |*a, **kw| [a, kw] } == [[], { a: 1 }])
check(A.yield_through(y, :hash) { |*a, **kw| [a, kw] } == [[{ a: 1 }], {}])
check(A.yield_through(y, :both) { |*a, **kw| [a, kw] } == [[1], { b: 2 }])

# rb_stat_new: the File::Stat of a struct stat C filled.
st = A.stat_new(__FILE__)
own = File.stat(__FILE__)
check(st.instance_of?(File::Stat))
# (not the device: on Linux ruby keeps a statx, and what it copies from a
#  struct stat leaves the device numbers out)
check([st.size, st.ino, st.mode, st.nlink, st.uid, st.gid] == [own.size, own.ino, own.mode, own.nlink, own.uid, own.gid])
check(st.file? && !st.directory? && st.mtime == own.mtime)
check((st <=> own) == 0)
check(A.stat_new(__dir__).directory?)
check(raises(Errno::ENOENT) { A.stat_new(__FILE__ + '.absent') }.is_a?(SystemCallError))

# The regexp parser's nesting bound is one number: what C sets, the parser
# obeys, and 0 puts the default back.
default = A.parse_depth
check(default == 4096)
nested = '(' * 30 + 'a' + ')' * 30
check(Regexp.new(nested).match?('a'))
check(A.set_parse_depth(10) == 0)
check(A.parse_depth == 10)
check(raises(RegexpError) { Regexp.new(nested) }.message.start_with?('parse depth limit over: /(((('))
check(raises(RegexpError) { Regexp.new('[' * 30 + 'a' + ']' * 30) }.message.start_with?('parse depth limit over: /[[[['))
check(Regexp.new('((a))').match?('a'))
check(A.set_parse_depth(0) == 0)
check(A.parse_depth == default)
check(Regexp.new(nested).match?('a'))

# rb_str_encode_ospath: UTF-8 on macOS unless the String is binary; the
# String itself elsewhere.
euc = "\u3042".encode('EUC-JP')
mac = RUBY_PLATFORM.include?('darwin')
check(A.ospath(euc).encoding == (mac ? Encoding::UTF_8 : Encoding::EUC_JP))
check(A.ospath(euc).bytes == (mac ? "\u3042".bytes : euc.bytes))
check(A.ospath(euc.b).equal?(euc.b) == false && A.ospath(euc.b).encoding == Encoding::BINARY)
utf = "\u3042"
check(A.ospath(utf).equal?(utf))
puts "api contracts: #{$count} passed"
