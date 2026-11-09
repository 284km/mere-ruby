# Kernel's functions called on Kernel read the caller's frame, and reach a
# class or module receiver through send.
module KB
  def self.a = Kernel.block_given?
  def self.b = yield_self { Kernel.block_given? }
  def self.c = self.send(:block_given?)
  def self.d = yield_self { self.send(:block_given?) }
end
p KB.a {}, KB.a, KB.b {}, KB.b, KB.c {}, KB.c, KB.d {}, KB.d
p Kernel.system("true"), Kernel.__dir__.class
module KQ; end
p((KQ.puts(1) rescue $!.message))
p((-> { fail }.call rescue $!.class))

# BasicObject's methods answer *_method_defined?, it names itself, and a
# class without Object above it sees none of the top level.
p BasicObject.public_method_defined?(:instance_eval), BasicObject.private_method_defined?(:method_missing)
p BasicObject.send(:public_method_defined?, :!), BasicObject.public_method_defined?(:method_missing)
p BasicObject.const_defined?(:Kernel), BasicObject.constants(false)
class KBO < BasicObject
  def self.kd = defined?(Kernel)
  def self.me = BasicObject
end
p KBO.kd, KBO.me
p BasicObject.singleton_class.instance_of?(Class), Object.new.singleton_class.instance_of?(Class)

# A class's own builtin precedes an ancestor's method of that name.
class Object; private def include(*) = :object_include; end
p Module.public_method_defined?(:include)
class Object; remove_method :include; end

# Module#constants lists a prepended module's; a frozen class refuses
# define_method from a class_eval block; define_method's |a,| takes one.
module KPM; KX = 1; end
class KPC; prepend KPM; end
p KPC.constants
p((Class.new.freeze.class_eval { define_method(:x) {} } rescue $!.class))
k = Class.new
k.class_eval("define_method(:m) { |a,| a }")
p((k.new.m(1, 2) rescue $!.class))
p k.new.m([1, 2])

# A singleton's alias of a builtin is listed among its methods.
class KDS; define_singleton_method(:consts, self.method(:constants)); end
p KDS.methods.include?(:consts), KDS.singleton_methods

# Conversion refusals in ruby's words.
x = Object.new; def x.to_str = 1
y = Object.new; def y.to_int = "a"
p((format("%c", x) rescue $!.message))
p((format("%c", y) rescue $!.message))
p((Module.new.class_eval(x) rescue $!.message))
p((BasicObject.new.instance_eval("1", "f", y) rescue $!.message))

# eval draws its own frames: the eval method's, then the code's, labelled like
# the frame it runs in (or the binding's).
def kef = eval("caller(0)[0, 3]")
p kef.map { |l| l.sub(/^.*?:\d+:/, "") }
def kbg = binding
p kbg.eval("caller(0)[0, 2]").map { |l| l.sub(/^.*?:\d+:/, "") }
p 1.then { eval("caller(0)[0]") }.sub(/^.*?:\d+:/, "")

# -n's helpers are module functions; the interpreter's own names are not
# constants of the program.
p Object.constants.include?(:ARGFClass), Object.constants.include?(:Enumerable__Impl), IO.constants.include?(:POPEN_IO_KEYS)

# A setter can forward all its arguments.
class KSet
  def pos=(...)
    @got = take(...)
  end
  def take(*a) = a
  attr_reader :got
end
s = KSet.new; s.pos = 3; p s.got
