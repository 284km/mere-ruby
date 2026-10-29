# M corners after sweep464: a Module-subclass instance as a `::` scope,
# Class#allocate held for Rational / Complex, __LINE__ in a heredoc body,
# arity messages counted first, the unused-block warning per call site and
# not through send, File.path asking #to_str.

def show(label)
  r = yield
  puts "#{label}: #{r.inspect}"
rescue Exception => e
  puts "#{label}: #{e.class}: #{e.message.gsub(/0x\h+/, "0x")}"
end

# an instance of a Module subclass is the module it backs to `::`
mc = Class.new(Module)
m = mc.new
show("const via ::") { m::A = 1; [m::A, m.constants] }
show("massign via ::") { m::B, m::C = 2, 3; [m::B, m::C] }

# Class#allocate, held, makes an uninitialized Rational / Complex
allocator = Class.instance_method(:allocate)
show("allocate Rational") { allocator.bind(Rational).call }
show("allocate Complex") { allocator.bind_call(Complex).class }

# __LINE__ in a heredoc's interpolation is the line it is written on
def take(s) = s
here = __LINE__
lines = take(<<-L) { 1 }
#{__LINE__ - here} #{__LINE__ - here}
#{__LINE__ - here}
L
show("heredoc __LINE__") { lines.split }

# the count is checked before the arguments are
show("define_method 3 args") { Module.send(:define_method, 1, 2, 3) }
show("SignalException 3 args") { SignalException.new(1, "", nil) }

# the unused-block warning: once per call site, never through send
warns = []
Warning.singleton_class.class_eval do
  alias_method :__corpus_warn, :warn
  define_method(:warn) { |msg, **| warns << msg[/:(\d+): warning: the block passed/, 1] }
end
$VERBOSE = true
def corpus_noblk = nil
base = __LINE__
corpus_noblk {}
send(:corpus_noblk) {}
b = Proc.new {}
corpus_noblk(&b)
2.times { corpus_noblk {} }
$VERBOSE = false
Warning.singleton_class.class_eval { alias_method :warn, :__corpus_warn }
show("unused block lines") { warns.compact.map { |l| l.to_i - base } }

# File.path converts with #to_str when there is no #to_path
show("File.path to_str") { File.path(Struct.new(:to_str).new("/x/y")) }
show("File.path to_str bad") { File.path(Struct.new(:to_str).new(42)).class }
