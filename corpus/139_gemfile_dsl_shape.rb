# Walking bundler's Gemfile evaluation turned up five gaps, each general Ruby.

# 1. The string form of `instance_eval` is answered BEFORE method_missing. A
#    class that defines method_missing -- bundler's Dsl does, to name an unknown
#    Gemfile directive -- was asked about `instance_eval` itself, and since the
#    Gemfile DSL *is* `instance_eval(contents, path, 1)`, that answer replaced
#    the whole evaluation.
class Dslish
  attr_reader :seen
  def initialize; @seen = []; end
  def source(x); @seen << [:source, x]; end
  def gem(name, *rest); @seen << [:gem, name]; end
  def method_missing(name, *args)
    raise NameError, "Undefined local variable or method `#{name}'"
  end
  def respond_to_missing?(name, include_private = false)
    true
  end
  def run(src, path)
    instance_eval(src, path, 1)   # implicit self, three arguments
    self
  end
end
p Dslish.new.run("source \"https://example.org\"\ngem \"rainbow\"\n", "(Gemfile)").seen
p Dslish.new.instance_eval("@seen = [:direct]; @seen")
# ... and a name the object really does not answer still reaches method_missing
begin
  Dslish.new.no_such_directive
rescue NameError => e
  p e.class
end

# 2. An exception answers #backtrace. mere-ruby records no call stack, so the
#    answer is nil where ruby has frames (see KNOWN_GAPS) -- what is tested here
#    is that ASKING does not raise, because a library reads a backtrace while it
#    is reporting an error, and a NoMethodError there hides the real one.
begin
  raise "boom"
rescue => e
  answered = begin
    e.backtrace
    true
  rescue NoMethodError
    false
  end
  p answered
end

# 3. Errno is a module holding the SystemCallError classes, and a library passes
#    it around as a value (`const_get_safely(:ENOTSUP, Errno)`).
p Errno.is_a?(Module)
p Errno::EPROTO.superclass
p [Errno.constants.include?(:EACCES), Errno.constants.include?(:ENOENT)]

# 4. Pathname answers .pwd and .getwd, not only .new.
require "pathname"
p [Pathname.pwd == Pathname.new(Dir.pwd), Pathname.getwd.to_s == Dir.pwd]

# 5. A Method object answers #call with a BLOCK. tsort (which bundler vendors,
#    and which its SpecSet includes) builds `method(:tsort_each_node)` and calls
#    it with the block that visits each node -- the plain dispatcher hands a
#    method no block, so the block has to be carried through the Method.
class Nodes
  def initialize(a); @a = a; end
  def each_node
    @a.each {|x| yield x }
    :walked
  end
end
m = Nodes.new([1, 2, 3]).method(:each_node)
seen = []
p m.call {|x| seen << x }
p seen
p m.() {|x| seen << x * 10 }
p seen
def forward(meth, &b); meth.call(&b); end
via_amp = []
forward(m) {|x| via_amp << x }
p via_amp

# ... and it may call a PRIVATE method, because it was obtained by name rather
# than through an implicit receiver -- tsort's tsort_each_node is private in
# bundler's SpecSet.
class Hidden
  def visible_method(m); m.call {|x| x }; end
  private
  def secret; yield :from_secret; :secret_done; end
end
h = Hidden.new
sm = h.method(:secret)
got = []
p sm.call {|x| got << x }
p got
begin
  h.secret { }
rescue NoMethodError => e
  p e.class
end
