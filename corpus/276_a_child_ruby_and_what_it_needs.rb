# What CRuby's tests need to start a child interpreter and hear back from it:
# the interpreter's own path, a status to read, main's include, a BEGIN that
# reports, and an IO flushed at exit -- plus the locals assert_operator and
# assert_raise read where nothing assigned them.

# locals assigned where nothing runs
def ao(o1, op, o2 = (predicate = true; nil), msg = nil)
  return [:pred, o1] if predicate
  [:op, o1.__send__(op, o2)]
end
p ao(1, :<, 2), ao([], :empty?)
def kw(a, k: (z = 3; 4)) = [k, z]
p kw(1, k: 9), kw(1)
def ens
  begin
    1
  rescue => e
  ensure
    return [:ens, e]
  end
end
p ens

# RbConfig.ruby is a method a program can see and replace
p defined?(RbConfig.ruby), File.executable?(RbConfig.ruby)
module RbConfig
  @r276 = :mine
  class << self
    alias_method :__orig_ruby276, :ruby
    undef ruby
    attr_reader :r276
    def ruby = __orig_ruby276
  end
end
p RbConfig.r276
module Q276
  def self.r = 0
  @r = 1
  class << self
    undef r
    attr_reader :r
  end
end
p Q276.r

# a child interpreter, its status, and what it writes back
rb = RbConfig.ruby
out = IO.popen([rb, "-e", "puts 6 * 7"], &:read)
p out
pid = spawn(rb, "-e", "exit 3")
Process.wait(pid)
p [$?.exitstatus, $?.success?, $?.coredump?, $?.signaled?]
r, w = IO.pipe
pid = spawn(rb, "-e", "at_exit { IO.new(#{w.fileno}, 'w').puts :from_at_exit }", w => w)
w.close
Process.wait(pid)
p r.read
r.close
err = IO.popen([rb, "-e", "BEGIN { raise ArgumentError, 'in begin' }; puts :never", err: [:child, :out]], &:read)
p err.include?("in begin (ArgumentError)"), err.include?("never"), $?.exitstatus

# main's include, splat and several at once
def inc276 = include(*[Comparable], Enumerable)
p inc276, Object.include?(Comparable)

# a Thread subclass whose new calls super
class Thr276 < ::Thread
  Made = []
  def self.new(*)
    th = super
    Made << th
    th
  end
end
t = Thr276.new { 2 + 3 }
p t.class, t.value, t.alive?, Thr276::Made.size

# super from a new prepended to a singleton, with an instance method_missing
class K276
  def initialize(a) = (@a = a)
  def method_missing(n, *) = "mm:#{n}"
end
K276.singleton_class.prepend(Module.new { def new(...) = super })
p K276.new(7).instance_variable_get(:@a)
