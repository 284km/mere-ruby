# Round 26 of note 545: Ruby::Box. A child started with RUBY_BOX=1 has boxes:
# each sees the booted interpreter and its own writes -- top-level constants,
# methods on the builtin classes, globals, $LOADED_FEATURES -- and code runs
# in the box it was read in (a method, a block, a binding). A class a box
# makes under a name another box has is a class of its own. (The child's
# stderr says the feature is experimental, naming the program: not compared.)
child = <<~'CHILD'
  p Ruby::Box.enabled?, Ruby::Box.current, Ruby::Box.main, Ruby::Box.root, Ruby::Box.master
  p Ruby::Box.main.main?, Ruby::Box.root.root?, Ruby::Box.current == Ruby::Box.main
  b = Ruby::Box.new
  p b, b.eval("x = 10; y = 20; x + y"), (b.eval("x") rescue $!.class)

  # a constant and a class of the box's own, and one with main's name
  class Foo; def m = :main; end
  b.eval("TEST_CONST = 42; class Foo; def x = 1; end")
  p b::TEST_CONST, (TEST_CONST rescue $!.class), b::Foo == Foo, b::Foo.name
  p b::Foo.new.x, b::Foo.new.respond_to?(:m), Foo.new.respond_to?(:x)

  # a builtin's method and a global, only in the box
  $gvar1 = "bar"
  b.eval('class Integer; def +(*) = 42; end; $gvar1 = "foo"')
  b.eval("class Foo; def self.g = [$gvar1, 1 + 2, Ruby::Box.current]; def self.yb = yield; end")
  p 1 + 2, $gvar1, b::Foo.g == ["foo", 42, b]
  p b::Foo.yb { Ruby::Box.current } == Ruby::Box.main

  # a binding made in the box evaluates there, and keeps the box alive
  bnd = b.eval("binding")
  b = nil
  GC.start
  p bnd.eval("1 + 2"), 1 + 2

  # each box has its own load list
  r = Ruby::Box.root
  $LOADED_FEATURES.push("/tmp/main_only")
  p r.eval('$LOADED_FEATURES.push("/tmp/root_only"); $LOADED_FEATURES.include?("/tmp/main_only")')
  p $LOADED_FEATURES.include?("/tmp/root_only")
  p r.eval("$a = 2; $a"), ($a = 1; $a)
  r.eval("class FromRoot; end")
  p Object.const_defined?(:FromRoot), r.eval("Object.const_defined?(:FromRoot)")
CHILD
IO.popen({ "RUBY_BOX" => "1" }, [RbConfig.ruby, "-e", child], err: File::NULL) { |io| puts io.read }

# (what the boxes needed, true without them too)
# a constant naming an anonymous module scopes a class written through it
X = Module.new
class X::Y; end
module X::Z; end
p X.constants.sort, X::Y.name
# an instance of a Module subclass asks its class's #const_missing
class MM < Module
  def const_missing(n) = [:missing, n]
end
TOP = 1
p MM.new::TOP, MM.new::Nope
