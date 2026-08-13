# Command words are ordinary method names, so they are ordinary local names
# too. rubocop writes both of these:
#   require = injectable_require_directive.chomp
#   attr_accessor = "attr_accessor #{macro.bisected_names.join(', ')}\n"
# and keyword parameter defaults may name a parameter that precedes them.

require = "a/b.rb"
p require
require += "!"
p require

include = 1
extend = 2
private = 3
public = 4
module_function = 5
p [include, extend, private, public, module_function]

names = %w[x y]
attr_accessor = "attr_accessor #{names.join(', ')}\n"
attr_reader = 0
attr_reader += 7
p attr_accessor
p attr_reader

# ...and the real declarations still declare.
class Point
  attr_accessor :x
  attr_reader :y
  attr_writer :z

  def initialize(x, y)
    @x = x
    @y = y
  end

  def zed
    @z
  end
end

pt = Point.new(1, 2)
pt.x = 10
pt.z = 30
p [pt.x, pt.y, pt.zed]

# a bare mention of the word, with no attribute name after it, is a call
class Bare
  def self.attr_reader(*args)
    "called with #{args.inspect}"
  end
  V = attr_reader
end
p Bare::V

# Ruby evaluates parameter defaults left to right, so a keyword default can
# name a positional or splat parameter declared before it.
def def_callback(type, *signature, arity: signature.size..signature.size)
  [type, signature, arity]
end
p def_callback(:send)
p def_callback(:send, :a, :b)
p def_callback(:send, :a, arity: 0..1)

def tail(a, b = a * 2, *rest, kw: a + b, **opts)
  [a, b, rest, kw, opts]
end
p tail(1)
p tail(1, 5, 9, extra: true)
p tail(1, 5, kw: 0)
