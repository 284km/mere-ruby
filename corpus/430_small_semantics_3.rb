# Small corners: an Array's own []= in a multiple assignment, a redefined
# Array#initialize_copy, a root of two slashes, the order a super call
# converts its arguments in, and the name of an anonymous namespace in a
# warning.
require "stringio"

def show(label)
  r = yield
  puts "#{label}: #{r.inspect}"
rescue => e
  puts "#{label}: #{e.class}: #{e.message}"
end

# the singleton's []= takes whatever it is given
a = []
def a.[]=(*args)
  push args
end
show("plain") { a["x", "y"] = 0; a }
show("masgn") { b, a["a", "b"] = 1, 2; a }
show("masgn trailing comma") { a["c", 10], = 3; a }

# the copy is what initialize_copy makes of it
class Hash
  alias __orig_ic initialize_copy
end
class Array
  alias __orig_ic initialize_copy
  undef initialize_copy
  def initialize_copy(*); end
end
show("dup") { [1, 2, 3].dup }
show("clone") { [1, 2, 3].clone }
show("slice dup") { x = [1, 2, 3, 4][1..-2].dup; x.push(9); x }
class Array
  undef initialize_copy
  alias initialize_copy __orig_ic
end
show("restored") { [1, 2, 3].dup }

# two leading slashes are kept
show("expand //") { [File.expand_path(".", "//"), File.expand_path("sub", "//"), File.expand_path("//x"), File.expand_path("/a/../b")] }

# super converts the keywords, then the block
class Base
  def t(*a, **k, &b) = [a, k, b.class]
end
class Sub < Base
  def t(o, splat)
    if splat
      super(*o, **o, &o)
    else
      super(**o, &o)
    end
  end
end
order = []
o = Object.new
o.define_singleton_method(:to_a) { order << :to_a; [] }
o.define_singleton_method(:to_hash) { order << :to_hash; {} }
o.define_singleton_method(:to_proc) { order << :to_proc; lambda {} }
show("super order") { Sub.new.t(o, false); r = order.dup; order.clear; Sub.new.t(o, true); [r, order] }

# an anonymous namespace in the redefinition warning
c = Class.new
c.const_set(:K, 1)
err = StringIO.new
$stderr = err
c.const_set(:K, 2)
$stderr = STDERR
show("warning") { err.string.lines.first.sub(/0x\h+/, "0x").sub(/\A.*?: /, "") }
