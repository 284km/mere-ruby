require 'stringio'
# (what loading the extension says on stderr: nothing -- its Init_ undefines
#  `initialize` from C, which is not the warning Module#undef_method gives)
stderr = $stderr
$stderr = StringIO.new
require 'api_fixture'
said = $stderr.string
$stderr = stderr
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
check(said == '')

# Native flags never call a Ruby predicate, including during mirror refresh.
[-> { Class.new }, -> { Module.new }, -> { Object.new }, -> { +'' },
 -> { [] }, -> { {} }, -> { proc {} }, -> { binding }].each do |factory|
  owner = factory.call
  $frozen_flag_queries = 0
  owner.define_singleton_method(:frozen?) { $frozen_flag_queries += 1; false }
  check(!A.frozen_flags(owner, 0))
  owner.freeze
  check(A.frozen_flags(owner, 0))
  check(A.frozen_flags(factory.call, 1))
  check(A.frozen_flags(factory.call, 2) { |value| value.freeze })
  check($frozen_flag_queries == 0)
end

# C's constant APIs also accept hidden cache names, as io-console's
# IO.console does. Ruby's own constant lookup must continue to reject them.
class HiddenConstParent; end
class HiddenConstChild < HiddenConstParent; end
[:console, :_cache].each do |name|
  check(!A.hidden_const_api(HiddenConstParent, name, 4, nil))
  check(A.hidden_const_api(HiddenConstParent, name, 0, false) == false)
  [1, 2, 3].each { |operation| check(A.hidden_const_api(HiddenConstParent, name, operation, nil) == false) }
  [4, 5, 6].each { |operation| check(A.hidden_const_api(HiddenConstParent, name, operation, nil)) }
  check(!HiddenConstParent.constants(false).include?(name))
  raises(NameError) { HiddenConstParent.const_get(name) }
  [1, 3].each { |operation| check(A.hidden_const_api(HiddenConstChild, name, operation, nil) == false) }
  [4, 6].each { |operation| check(A.hidden_const_api(HiddenConstChild, name, operation, nil)) }
  check(!A.hidden_const_api(HiddenConstChild, name, 5, nil))
  raises(NameError) { A.hidden_const_api(HiddenConstChild, name, 2, nil) }
  raises(NameError) { A.hidden_const_api(HiddenConstChild, name, 7, nil) }
  check(A.hidden_const_api(HiddenConstChild, name, 0, nil).nil?)
  check(A.hidden_const_api(HiddenConstChild, name, 5, nil))
  check(A.hidden_const_api(HiddenConstChild, name, 7, nil).nil?)
  check(!A.hidden_const_api(HiddenConstChild, name, 5, nil))
  check(A.hidden_const_api(HiddenConstParent, name, 7, nil) == false)
  check(!A.hidden_const_api(HiddenConstParent, name, 4, nil))
  frozen_owner = Class.new
  A.hidden_const_api(frozen_owner, name, 0, false)
  frozen_owner.freeze
  raises(FrozenError) { A.hidden_const_api(frozen_owner, name, 7, nil) }
  check(A.hidden_const_api(frozen_owner, name, 5, nil))
end

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
# Two stopped C calls hold pointers into the SAME String: each one's write
# goes back when it is resumed, the first to end does not end the other's
# watch (and the other order; two Strings are the control).
[[:a, :b, 'Ybc'], [:b, :a, 'Xbc']].each do |first, second, want|
  s = +'abc'
  fibers = { a: Fiber.new { A.byte_after_yield(s, 'X'.ord) { Fiber.yield } },
             b: Fiber.new { A.byte_after_yield(s, 'Y'.ord) { Fiber.yield } } }
  fibers[:a].resume
  fibers[:b].resume
  fibers[first].resume
  check(s == (first == :a ? 'Xbc' : 'Ybc'))
  fibers[second].resume
  check(s == want)
end
s1, s2 = +'abc', +'abc'
fa = Fiber.new { A.byte_after_yield(s1, 'X'.ord) { Fiber.yield } }
fb = Fiber.new { A.byte_after_yield(s2, 'Y'.ord) { Fiber.yield } }
fa.resume; fb.resume; fa.resume; fb.resume
check([s1, s2] == ['Xbc', 'Ybc'])

# A primitive is ruby's operation, not the method a subclass (or the object's
# singleton) defined under its name.
class OverArray < Array
  def push(*) = :intercepted
  def [](*) = :intercepted
  def []=(*)
    :intercepted
  end
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
# rb_ary_store and rb_obj_freeze are ruby's operations, with no method called
# (an Array at its end is appended and a String, an Array or a Hash frozen by
# a flag here; anything else is the builtin's call): at the end, past it
# (nil between), in the middle, from the end, too far from the end, on a
# frozen Array; a subclass's #[]= and #freeze are not called
check(A.store([1, 2], 2, 3) == [1, 2, 3] && A.store([1], 3, 4) == [1, nil, nil, 4])
check(A.store([1, 2, 3], 1, :b) == [1, :b, 3] && A.store([1, 2, 3], -1, :z) == [1, 2, :z])
e = raises(IndexError) { A.store([1, 2], -3, 0) }
check(e.message == 'index -3 too small for array; minimum: -2')
e = raises(FrozenError) { A.store([1, 2].freeze, 2, 3) }
check(e.message == "can't modify frozen Array: [1, 2]")
ox = OverArray.new
check(A.store(ox, 0, :a).to_a == [:a] && A.store(ox, 1, :b).to_a == [:a, :b])
fa = [1]
fh = { a: 1 }
fs = +'s'
A.freeze(fa); A.freeze(fh); A.freeze(fs)
check(fa.frozen? && fh.frozen? && fs.frozen?)
e = raises(FrozenError) { fs << 'x' }
check(e.message == "can't modify frozen String: \"s\"")
list, len, last, frozen = A.row(5)
check(list == [0, 'text', 2, 'text', 4] && len == 5 && last == 4 && frozen && list.frozen?)
check(list[1].frozen? && A.row(0) == [[], 0, nil, true])
# rb_default_internal_encoding answers what Encoding.default_internal was
# last set to, nil when it was cleared
verbose = $VERBOSE
$VERBOSE = nil
before = Encoding.default_internal
Encoding.default_internal = 'ISO-8859-1'
check(A.default_internal == Encoding::ISO_8859_1)
Encoding.default_internal = nil
check(A.default_internal.nil?)
Encoding.default_internal = before
$VERBOSE = verbose
check(A.kind_of(oo, String) == false)
single = [1]
def single.push(*) = :intercepted
A.push(single, 2)
check(single == [1, 2])
plain = []
A.push(plain, 1)
check(plain == [1])
check(A.aref(oa, 0) == 7)
check(A.aref([5, 6], 1) == 6)
# ...nor a definition the program made in the builtin class itself
class String
  alias_method :__capi_length, :length
  def length = 999
end
check('abc'.length == 999)
check(A.length('abc') == 3)
class String
  alias_method :length, :__capi_length
  remove_method :__capi_length
end
check('abc'.length == 3 && A.length('abc') == 3)
class Array
  alias_method :__capi_push, :push
  def push(*) = :intercepted
end
redef = []
check(redef.push(1) == :intercepted)
A.push(redef, 2)
check(redef == [2])
class Array
  alias_method :push, :__capi_push
  remove_method :__capi_push
end
check([].push(1) == [1])
# ...nor a module prepended to the builtin class (switched off afterwards:
# a prepend cannot be undone)
module CapiPrepended
  def push(*items) = ($capi_prepended ? :intercepted : super)
end
Array.prepend(CapiPrepended)
$capi_prepended = true
pre = []
check(pre.push(1) == :intercepted)
A.push(pre, 2)
check(pre == [2])
$capi_prepended = false
check([].push(1) == [1])

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
check(ApiFixture::Mid::Leaf.allocate.extra == :reopened)
check(raises(NoMethodError) { ApiFixture::Mid::Leaf.new }.name == :new)
check(Custom.new.extra == :reopened)

# rb_proc_new makes a Proc, not a lambda.
pr = A.new_proc
check(pr.lambda? == false)
check(pr.call(5, 6) == [5, 2, :data])
check([[1, 2]].map(&pr) == [[[1, 2], 1, :data]])
# What real gems asked for. A conversion by method name, and its three
# refusals; equal bytes hash equally; every instance variable is visited; the
# last match is the calling frame's; digits of a base; the struct behind an IO.
class ToHash
  def initialize(v) = @v = v
  def to_hash = @v
end
check(A.convert({ a: 1 }, false) == { a: 1 })
check(A.convert(ToHash.new({ b: 2 }), false) == { b: 2 })
check(raises(TypeError) { A.convert(3, false) }.message == 'no implicit conversion of Integer into Hash')
check(raises(TypeError) { A.convert(nil, false) }.message == 'no implicit conversion of nil into Hash')
check(raises(TypeError) { A.convert(ToHash.new(5), false) }.message == "can't convert ToHash to Hash (ToHash#to_hash gives Integer)")
check(A.convert(3, true).nil?)
check(A.convert(ToHash.new(nil), true).nil?)
check(A.convert(ToHash.new({ c: 3 }), true) == { c: 3 })
check(raises(TypeError) { A.convert(ToHash.new(5), true) }.message == "can't convert ToHash to Hash (ToHash#to_hash gives Integer)")
check(A.memhash_equal('same bytes', +'same bytes') == true)
check(A.memhash_equal('same bytes', 'other') == false)
holder = Object.new
holder.instance_variable_set(:@one, 1)
holder.instance_variable_set(:@two, [2])
check(A.ivars(holder) == [[:@one, 1], [:@two, [2]]])
check(A.ivars(Object.new) == [])
def matched
  'key=value' =~ /(\w+)=(\w+)/
  [A.last_match(0), A.last_match(2), A.last_match(5)]
end
check(matched == ['key=value', 'value', nil])
def carried(m)
  A.set_match(m)
  [$~.equal?(m), $1]
end
check(carried(/(b)/.match('abc')) == [true, 'b'])
# (in a block a Ruby method yields to -- how mspec runs an example -- and at
#  the top level: the C method's frame stands at two depths in the first, and
#  the caller of the second is the main script's)
def yielder = yield
check(yielder { /(c)d/ =~ 'cd'; A.last_match(1) } == 'c')
/(e)f/ =~ 'ef'
check(A.last_match(1) == 'e')
A.set_match(/(g)/.match('g'))
check($1 == 'g')
# (a C method has no `$~` of its own: a Fiber's and a Thread's body have
#  theirs, and public_send / class_eval / module_eval have none in between)
/(outer)/ =~ 'outer'
check(Fiber.new { /(inner)/ =~ 'inner'; [$1, A.last_match(1)] }.resume == ['inner', 'inner'])
check(Thread.new { /(inner)/ =~ 'inner'; [$1, A.last_match(1)] }.value == ['inner', 'inner'])
check($1 == 'outer')
written = /(written)/.match('written')
/(outer)/ =~ 'outer'
Fiber.new { A.set_match(written) }.resume
check($1 == 'outer')
Thread.new { A.set_match(written) }.join
check($1 == 'outer')
def through_public_send
  /(x)/ =~ 'x'
  [A.last_match(1), A.public_send(:last_match, 1)]
end
check(through_public_send == ['x', 'x'])
check(Object.class_eval { /(y)/ =~ 'y'; [$1, A.last_match(1)] } == ['y', 'y'])
check(Object.module_eval { /(z)/ =~ 'z'; [$1, A.last_match(1)] } == ['z', 'z'])
# (CLASS_OF of an instance of a builtin's subclass is the subclass: sqlite3
#  binds a SQLite3::Blob, a String subclass, as a BLOB by its class)
class SubString < String; end
class SubArray < Array; end
class SubHash < Hash; end
check(A.class_of(SubString.new('x')) == SubString)
check(A.class_of(SubArray.new([1])) == SubArray)
check(A.class_of(SubHash.new) == SubHash)
check(A.class_of('plain') == String && A.class_of([]) == Array && A.class_of({}) == Hash)
# CLASS_OF of a class is its metaclass, which CRuby makes with every class,
# and a class variable of a module it includes is read through it
# (cgi/escape's @@accept_charset)
module CvarM; @@cv = :from_module; end
class CvarC; include CvarM; end
check(A.class_of(CvarC) == CvarC.singleton_class && A.class_of(CvarC).singleton_class?)
check(A.cvar_of_class_of(CvarC, '@@cv') == :from_module)
# (what io-console and prism asked for: ruby_version is RUBY_VERSION; the
#  write IO of a plain IO is itself; nothing is pending before a read, and
#  what a partial read left buffered is)
check(A.version_text == RUBY_VERSION)
pr, pw = IO.pipe
check(A.write_io_of(pr).equal?(pr) && A.write_io_of(pw).equal?(pw))
check(A.read_pending(pr) == 0)
pw.write("abcdef"); pw.close
check(pr.getc == "a")
check(A.read_pending(pr) == 5)
# (a duplex IO's write half: the same one each time, writes reach the child,
#  and it is closed with the IO -- CRuby's tied writer)
dio = IO.popen(['cat'], 'r+')
dw = A.write_io_of(dio)
check(A.write_io_of(dio).equal?(dw))
dw.write("duplex\n")
check(dio.gets == "duplex\n")
dio.close
check(dw.closed?)
# (closing either half unties it: io itself answers, and close_read takes
#  the writer with it)
dio = IO.popen(['cat'], 'r+')
dio.close_write
check(A.write_io_of(dio).equal?(dio))
dio.close
dio = IO.popen(['cat'], 'r+')
dw = A.write_io_of(dio)
wfd = A.write_descriptor(dio)
dio.close_read
check(dw.closed? && A.write_io_of(dio).equal?(dio))
# (...and from then on the IO is its write half: its number, and the one C
#  writes on, is the writer's -- not the read descriptor close_read closed)
check(dio.fileno == wfd && A.write_descriptor(dio) == wfd)
dio.close
# (both halves closed, in either order: the IO is closed, its child waited for)
[%i[close_read close_write], %i[close_write close_read]].each do |first, second|
  dio = IO.popen(['cat'], 'r+')
  pid = dio.pid
  dio.send(first)
  dio.send(second)
  check(dio.closed? && $?.pid == pid)
end
pr.close
check(A.strtoul('  0x1fz', 0) == [31, 6])
check(A.strtoul('-12', 10) == [2**64 - 12, 3])
check(A.strtoul('777', 8) == [511, 3])
File.open(__FILE__) do |f|
  check(A.io_facts(f) == [1, true, false])
end
rd, wr = IO.pipe
check(A.io_facts(rd) == [1, true, false])
check(raises(IOError) { A.io_facts(wr) }.message == 'not opened for reading')
rd.close
check(raises(IOError) { A.io_facts(rd) }.message == 'closed stream')
wr.close
# An IO's struct says the directions of THAT IO, not of its descriptor: a
# read-only wrapper on a descriptor opened for both is read-only to C too.
# (a file of its own, not Tempfile: loading tempfile under a collection at
#  every safepoint takes minutes)
path = File.join(ENV.fetch('TMPDIR', '/tmp'), "capi-io-#{Process.pid}")
begin
  both = File.open(path, 'w+')
  ro = IO.for_fd(both.fileno, 'r', autoclose: false)
  wo = IO.for_fd(both.fileno, 'w', autoclose: false)
  check(A.io_mode(both) == [true, true, false])
  check(A.io_mode(ro) == [true, false, false])
  check(A.io_mode(wo) == [false, true, false])
  check(raises(IOError) { A.io_check_writable(ro) }.message == 'not opened for writing')
  check(A.io_check_writable(wo) == true)
  File.open(path, 'a') { |app| check(A.io_mode(app) == [false, true, true]) }
  both.close
  # FMODE_EXTERNAL: the descriptor stays C's
  fd = IO.sysopen(path)
  ext = A.open_descriptor(fd, true)
  check(ext.autoclose? == false)
  ext.close
  check(IO.for_fd(fd, autoclose: false).fileno == fd)
  own = A.open_descriptor(fd, false)
  check(own.autoclose? == true)
  own.close
ensure
  File.delete(path) if File.exist?(path)
end
check(A.io_mode($stdin)[0..1] == [true, false] && A.io_mode($stdout)[0..1] == [false, true])

# A global C keeps, defined under a name aliased before: both names are the
# variable C holds.
alias $capi_dest $capi_src
A.keep_variable('$capi_dest')
A.kept_set(5)
check($capi_dest == 5 && $capi_src == 5)
$capi_src = 7
check(A.kept_get == 7 && $capi_dest == 7)
$capi_dest = 8
check(A.kept_get == 8 && $capi_src == 8)
A.keep_variable('$capi_plain')
$capi_plain = :p
check(A.kept_get == :p)

# The Set functions are set.c's operations: an override of the Ruby
# interface -- in a singleton or a subclass -- does not change them.
s = Set[1]
class << s
  %i[add? add include? delete? delete size each to_a clear].each do |m|
    define_method(m) { |*| raise "#{m} intercepted" }
  end
end
check(A.set_ops(s) == [true, false, true, false, 2, true, false, [2]])
check(A.set_clear(s) == 0)
class SubSet < Set
  def add?(*) = raise('intercepted')
  def include?(*) = raise('intercepted')
end
sub = SubSet[1]
check(A.set_ops(sub) == [true, false, true, false, 2, true, false, [2]])
check(A.set_ops(Set[1]) == [true, false, true, false, 2, true, false, [2]])
frozen = Set[1].freeze
check(raises(FrozenError) { A.set_add(frozen, 3) }.message.start_with?("can't modify frozen Set"))

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
check([st.size, st.ino, st.mode, st.nlink, st.uid, st.gid] == [own.size, own.ino, own.mode, own.nlink, own.uid, own.gid])
# (on Linux ruby keeps a statx, and what it copies from a struct stat leaves
#  the device numbers and the block size out: they read 0)
linux = RUBY_PLATFORM.include?('linux')
check([st.dev, st.rdev, st.blksize] == (linux ? [0, 0, 0] : [own.dev, own.rdev, own.blksize]))
check(st.file? && !st.directory? && st.mtime == own.mtime && st.atime == own.atime && st.ctime == own.ctime)
check((st <=> own) == 0 && st == own)
check(A.stat_new(__dir__).directory?)
check(raises(Errno::ENOENT) { A.stat_new(__FILE__ + '.absent') }.is_a?(SystemCallError))
# the struct's times to the nanosecond, and on macOS its birth time
made = A.stat_made_up(444555666)
check([made.atime, made.mtime, made.ctime].map { |t| [t.to_i, t.nsec] } == [[100, 111222333], [200, 444555666], [300, 777888999]])
check(made.size == 42 && made.file? && made.mode == 0o100644)
if RUBY_PLATFORM.include?('darwin')
  check([made.birthtime.to_i, made.birthtime.nsec] == [50, 123456789])
else
  check(raises(NotImplementedError) { made.birthtime }.message.include?('birthtime'))
end
# two snapshots a nanosecond apart are not the same, and are ordered by it
check((made <=> A.stat_made_up(444555667)) == -1)
check((made <=> A.stat_made_up(444555666)) == 0)
check(made != A.stat_made_up(444555665))
# NULL: an uninitialized File::Stat
blank = A.stat_null
check(blank.instance_of?(File::Stat))
check(raises(TypeError) { blank.mtime }.message == 'uninitialized File::Stat')
check(raises(TypeError) { blank.size }.message == 'uninitialized File::Stat')

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
# at the bound and one past it: the pattern itself is the first level
check(A.set_parse_depth(1) == 0)
check(Regexp.new('a').match?('a'))
%w[(a) (?:a) [a]].each { |src| check(raises(RegexpError) { Regexp.new(src) }.message.start_with?('parse depth limit over')) }
check(A.set_parse_depth(2) == 0)
%w[(a) (?:a) [a] a|(b)].each { |src| check(Regexp.new(src).match?('a') || Regexp.new(src).match?('b')) }
%w[((a)) [[a]] ([a]) (?:(?:a))].each { |src| check(raises(RegexpError) { Regexp.new(src) }.message.start_with?('parse depth limit over')) }
check(A.set_parse_depth(3) == 0)
check(Regexp.new('((a))').match?('a') && Regexp.new('[[a]]').match?('a'))
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
# (rb_funcallv_public calls the method, not what the class made of
#  `public_send`, and still refuses a private one)
class PublicSendOverride
  def public_send(*) = :overridden
  def m = :real
  private def hidden = :no
end
check(A.funcall_public(PublicSendOverride.new, :m) == :real)
check((A.funcall_public(PublicSendOverride.new, :hidden) rescue $!.class) == NoMethodError)
check((A.funcall_public(PublicSendOverride.new, :hidden) rescue $!.message) ==
      "private method 'hidden' called for an instance of PublicSendOverride")
# (...and the way in it takes is no name Ruby code can call)
check((1.__capi_public_send(:to_s) rescue $!.class) == NoMethodError)
# (C's rb_fs holds a value without identity across a collection)
old_fs = $;
begin
  $VERBOSE, verbose = nil, $VERBOSE
  $; = /,/
  GC.start
  check(A.fs_value == /,/)
ensure
  $; = old_fs
  $VERBOSE = verbose
end
# (an encoding index past the 7 bits of the flags: the 30th dummy defined
#  from C, read back from a String in it)
last = nil
30.times { |i| last = "CapiDummy#{i}"; A.define_dummy(last) }
dummy = Encoding.find(last)
check(A.enc_index_of("x".dup.force_encoding(dummy)) == Encoding.list.index(dummy))
check(Encoding.list.index(dummy) >= 127)
# (Kernel#binding from C is refused; a Proc's #binding is not)
check(A.binding_of(proc { 1 }).is_a?(Binding))
check((A.binding_of(Object.new) rescue $!.class) == RuntimeError)
check((A.binding_of(binding) rescue $!.class) == RuntimeError)
# (memsize_of a typed data wrapping NULL: its dsize is not asked)
require 'objspace'
check(ObjectSpace.memsize_of(A.null_typed).is_a?(Integer))
# rb_protect's state for each way out of a block, as C sees it (CRuby's
# TAG_*: return 1, break 2, raise 6, throw 7, and 0 for a value -- a `next`
# is the block's value), and rb_jump_tag carries the flow on
check(A.protect_state { break :b } == :b && A.last_state == 2)
def api_protect_return = (A.protect_state { return :r }; :not_returned)
check(api_protect_return == :r && A.last_state == 1)
check(A.protect_state { next :n } == :n && A.last_state == 0)
check(catch(:api_t) { A.protect_state { throw :api_t, 5 }; :no } == 5 && A.last_state == 7)
check((A.protect_state { raise 'x' } rescue $!.message) == 'x' && A.last_state == 6)
# (a Ruby rescue clears what an earlier rb_protect left in errinfo)
check(A.protect_and_return != 0)
check(A.errinfo_now.is_a?(ArgumentError))
begin
  raise "E2"
rescue
  check(A.errinfo_now.nil?)
end
# (...and it is each Fiber's own: one an rb_protect left on a Fiber is not
#  main's, nor a new Fiber's, and is still that Fiber's when it resumes)
check(A.errinfo_now.nil?)
f = Fiber.new { A.protect_and_return; Fiber.yield A.errinfo_now.class; A.errinfo_now.class }
check(f.resume == ArgumentError)
check(A.errinfo_now.nil?)
check(Fiber.new { A.errinfo_now }.resume.nil?)
GC.start
check(f.resume == ArgumentError)
check(A.errinfo_now.nil?)

# (Bignums C made in Init_ and kept the public ways are still there later,
#  and still zero -- rb_big_new gives digits of zero)
GC.start
check(A.kept_bignums == [0, 0])
check(A.kept_bignums == [0, 0])
# (...and one a slot held, taken out into a C local and used after a
#  nested C call: still there)
[false, true].each do |by_block|
  A.slot_fill
  GC.start
  check(A.slot_swap(by_block) == 0)
end
# (...and while a Fiber is paused inside that C call, the slot is filled
#  and overwritten from outside it: the paused local still has its own)
A.slot_fill
paused = Fiber.new { A.slot_swap_yield { Fiber.yield } }
paused.resume
3.times { A.slot_fill }
GC.start
A.noop
check(paused.resume == 0)

# rb_check_id answers the ID of a name ruby has as one -- a builtin's name,
# a method the program defined -- also after #to_sym of it; a name only
# #to_sym made is a dynamic Symbol, which rb_check_symbol finds and
# rb_check_id does not, until a definition pins it. (The names are built so
# that this source does not write them.)
builtin = 'lj' + 'ust'
check(builtin.to_sym.is_a?(Symbol))
check(A.check_id(builtin))
check(A.check_id(builtin.to_sym))
defined = 'api_dm_' + 'q9'
Class.new.define_method(defined) {}
check(defined.to_sym.is_a?(Symbol))
check(A.check_id(defined))
fresh = 'api_fresh_' + 'q9'
check(!A.check_id(fresh))
check(A.check_symbol(fresh).nil?)
sym = fresh.to_sym
check(!A.check_id(fresh))
check(!A.check_id(sym))
check(A.check_symbol(fresh) == sym)
check(A.check_symbol(sym) == sym)
Class.new.define_method(sym) {}
check(A.check_id(fresh))
check(A.check_id(sym))

# (without the GVL, with no other Ruby thread alive: the function runs on
#  the caller's native thread, and sees the __thread value C set)
check(Thread.list.size == 1 && A.nogvl_tls == 42)
# (...and errno is what the function left, whichever native thread it ran
#  on: alone, and with another thread alive)
check(A.nogvl_errno == [-1, 1])
other = Thread.new { sleep 5 }
check(A.nogvl_errno == [-1, 1])
other.kill
# (without the GVL: another thread runs while the function naps; the
#  function can call back into Ruby; a kill ends a blocking read)
ticks = 0
ticker = Thread.new { 20.times { ticks += 1; sleep 0.01 } }
check(A.nogvl_nap(400) == true)
ticker.join
check(ticks == 20)
check(A.nogvl_call_back([]) == [1])
rd, wr = IO.pipe
reader = Thread.new { A.nogvl_read(rd.fileno) }
sleep 0.1
reader.kill
check(reader.join(5).equal?(reader))
rd.close; wr.close
# (...a raise that a function cannot be woken for: the other threads still
#  run until it ends, and then it is raised)
ticks = 0
ticker = Thread.new { loop { ticks += 1; sleep 0.01 } }
napper = Thread.new { A.nogvl_stubborn(400) }
sleep 0.05
napper.raise(ArgumentError, "stop")
at_raise = ticks
ended = (napper.value rescue $!.class)
seen = ticks
ticker.kill
check(ended == ArgumentError)
check(seen > at_raise)
# (...and a call back into Ruby that raises: the function ends, the
#  exception reaches the caller, and the next call works)
3.times { check((A.nogvl_call_raise rescue $!.message) == "from with_gvl") }
check(A.nogvl_call_back([]) == [1])

# A String's bytes in the struct or in a buffer of their own: C reads the
# same String either way, also when Ruby grew it between two looks, and the
# room the API promises is there.
s = +'ab'
first, copy = A.grown_by_ruby(s, 'c' * 100)
check(first == 'a'.ord && copy == 'ab' + 'c' * 100 && s == copy)
s = +'xyz'
check(A.cat_self(s, 4).equal?(s) && s == 'xyz' * 16)
ok, filled = A.buf_fill(5)
check(ok && filled == 'zzzzz')
ok, filled = A.buf_fill(3000)
check(ok && filled == 'z' * 3000)
check(A.expand_room(+'abc', 1000) == 1000)
check(A.expand_room(+('abc' * 100), 5000) == 5000)
# OBJ_FREEZE keeps a String's buffer, so a pointer C holds still reads its
# bytes; rb_str_freeze (String#freeze) resizes to the length, which puts
# 3 bytes back into the smallest slot (its room: the slot less the 24-byte
# header and the terminator)
seen, kept, resized, frozen = A.freeze_keeps_room
check(seen == 'abc' && kept == 1024 && resized == GC::INTERNAL_CONSTANTS[:BASE_SLOT_SIZE] - 25 && frozen)
far, back = A.resize_out_and_back(+'hello')
check(far == 'q' && back == 'he')
# String.new(capacity:) and a read into a buffer give the room they ask for
# (string.c's rb_str_s_new, io.c's io_setstrbuf), and the String keeps it
s = String.new(capacity: 5000)
check(A.capacity(s) == 5000)
s << 'abc'
check(A.capacity(s) == 5000 && s == 'abc')
buf = String.new
File.open(__FILE__) { |f| f.read(70000, buf) }
check(A.capacity(buf) == 70000 && buf == File.binread(__FILE__))
# What C holds only in its locals survives every collection the requests it
# makes can run (mr_up's safepoint): a String and an Array C made, across
# 120 Strings made and dropped and 120 calls -- and the same with the call
# paused halfway in a Fiber while the program makes garbage and collects.
digits = (0...120).sum { |i| i.to_s.size }
names = (0...8).map { |i| "e#{i}" }
held, ary, sum = A.hold_locals(120)
check(held == 'held-string' && ary == names && sum == digits)
paused = Fiber.new { A.hold_locals(120) { |i| Fiber.yield(i) } }
check(paused.resume == 60)
junk = (0...200).map { |i| ('x' * 4096) + i.to_s }
junk = nil
GC.start
held, ary, sum = paused.resume
check(held == 'held-string' && ary == names && sum == digits && !paused.alive?)
# What C writes into a frozen String's buffer is that String's bytes, as in
# ruby: the write-back raised FrozenError out of the C call instead
s = (+'abc').freeze
seen, same = A.write_frozen(s)
check(seen == 'Zbc' && same.equal?(s) && s == 'Zbc' && s.frozen?)
# A long C call that makes its garbage through the C API alone is collected
# in as it goes, as ruby's malloc limit collects in it: with no Ruby
# statement in it there was no safepoint here, and puma's parser held
# gigabytes until it returned (mr_up's safepoint)
joined, collections = A.join_in_c(400)
check(joined == (['test'] * 400).join(', ') && collections > 0)
# What C was lent stays where it was and as it was across the collections in
# the middle of the call that was lent it, and what C holds only in its
# locals outlives them: a String past any struct's room (its own buffer)
# and one in the struct, each with collections in the call
[+('lent' * 25_000), +'short'].each do |s|
  rest = s[1..]
  same, intact, held, ary, seen, collections = A.lent_across_collections(s, 400)
  check(same && intact && held == 'held-only-in-c' && ary == %w[a b] && collections > 0)
  check(seen == 'W' + rest && s == 'W' + rest)
end
puts "api contracts: #{$count} passed"
