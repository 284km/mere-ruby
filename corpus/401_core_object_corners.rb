# What ruby/spec's Proc, Method, Queue, Tempfile and File files ask of the
# corners: a Proc subclass, currying a curried proc, a copy's finalizers and
# instance variables, the thread classes' names, Tempfile's checks, File's
# flags and permissions, define_method's body argument, and a module
# prepended to Integer calling super
require "tempfile"
require "rbconfig"

def try401
  yield
rescue StandardError, ScriptError => e
  [e.class, e.message.sub(/0x\h+/, "XX")]
end

p proc { |_, _, _ = 1, *_, **_, &_| }.parameters

class MyProc401 < Proc
  attr_reader :ok
  def initialize(a = nil)
    @ok = a
    super()
  end
  def initialize_clone(other) = (@cloned = :clone)
  def cloned = @cloned
end
pr = MyProc401.new(3) { :called }
p pr.class, pr.call, pr.ok, MyProc401.new(&pr).equal?(pr), pr.clone.class, pr.clone.cloned
p try401 { MyProc401.new }

add = proc { |x, y, z| (x || 0) + (y || 0) + (z || 0) }
p add.curry[1, 2].curry[3, 4, 5, 6]
l = ->(a, b, c) { a + b + c }
p l.curry.call(1).curry.call(2, 3)

m = 1.method(:+)
m.instance_variable_set(:@ivar, 1)
p m.dup.instance_variables, Integer.instance_method(:+).tap { |u| u.instance_variable_set(:@x, 2) }.clone.instance_variables

p Queue.name, SizedQueue.new(1).inspect.sub(/0x\h+/, "XX"), Mutex.new.to_s.sub(/0x\h+/, "XX")
q = SizedQueue.new(2)
p try401 { q.max = "foo" }, (q.max = 3.0), q.max, try401 { SizedQueue.new(Object.new) }

p try401 { "w" | 1 }, try401 { 1.5 & 1 }, "ab".freeze.delete("b")

a = [:a, :b]
seen = []
i = 0
a.inject(nil) { |_, e| seen << e; a << i if i < 3; i += 1 }
p seen

p try401 { Tempfile.create(:x) {} }, try401 { Tempfile.create(["a", :b]) {} }, try401 { Tempfile.create("a", 1) {} }
Tempfile.create("t401") { |f| p f.class, File.stat(f.path).mode & 0777, File.basename(f.path).start_with?("t401") }
Tempfile.create(anonymous: true) { |f| p f.path.end_with?("/"), File.exist?(f.path) }
t = Tempfile.new(["t401", ".txt"], encoding: "Shift_JIS")
p t.external_encoding, File.extname(t.path), File.stat(t.path).mode & 0777
t.close!

Dir.mktmpdir do |dir|
  fn = File.join(dir, "f401.txt")
  File.write(fn, "hello file\n")
  p try401 { File.new(Object.new) }, try401 { File.new(true) }, try401 { File.new(-1) }
  p try401 { File.open(File.join(dir, "none"), File::WRONLY) }.first
  File.open(fn, File::TRUNC | File::WRONLY) {}
  p File.read(fn)
  File.write(fn, "x")
  File.chmod(0, fn)
  p try401 { File.open(fn) }.first, try401 { File.open(fn, "w") }.first
  File.chmod(0644, fn)
  File.open(fn, "r+b") { |f| p f.binmode? }
  File.open(fn, "rb") { |f| p f.binmode? }
  p File.new(fn) { raise "not called" }.class
end

dm = Class.new { define_method(:t, -> { :method }) { :block } }
p dm.new.t
bo = Class.new(BasicObject) { define_method :instance_of?, ::Object.instance_method(:instance_of?) }
p bo.new.instance_of?(bo)
sc = Class.new { class << self; def foo; end; end }
p try401 { Class.new { define_method :bar, sc.method(:foo) } }

module M401; end
class Integer
  prepend M401
end
M401.module_eval do
  def +(o)
    $called401 = true
    super(o)
  end
end
p 1 + 2, $called401

out = IO.popen([RbConfig.ruby, "-e", <<~'RUBY'], &:read)
  o = Object.new
  ObjectSpace.define_finalizer(o, proc { puts "obj" })
  o.dup
  pr = proc {}
  ObjectSpace.define_finalizer(pr, proc { puts "proc" })
  pr.clone
  exit 0
RUBY
p out.lines.sort
