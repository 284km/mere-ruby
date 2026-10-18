# Threads as test_thread asks (note 371): Thread.kill takes only a thread
# (TypeError), join's limit is converted as rb_num2dbl converts it (#to_f,
# a limit past a Float's precision is none, "can't convert X into Float"),
# Thread#fetch's KeyError carries its key and receiver, handle_interrupt's
# mask must be a Hash, a subclass #initialize that never reaches super is an
# uninitialized thread whatever it raised, and a Thread subclass's own
# methods reach its builtin surface by bare name (`name`, `alive?`,
# `pending_interrupt?`, before super too).
def t(name)
  r = begin; yield; rescue Exception => e; "#{e.class}: #{e.message.sub(/0x\h+/, "0xX")}"; end
  p [name, r]
end
t(:kill_nil) { Thread.kill(nil) }
t(:kill_obj) { Thread.kill(Object.new) }
th = Thread.new {}; Thread.pass while th.status
t(:join_sym) { th.join(:foo) }
t(:join_to_f) { th.join(Struct.new(:to_f, :count).new(0.05)).equal?(th) }
t(:join_big) { th.join(18446744073709551615).equal?(th) }
t(:join_inf) { th.join(Float::INFINITY).equal?(th) }
s = Thread.new { sleep }
s["foo"] = "foo"
t(:fetch) { [s.fetch(:foo, 0), s.fetch("foo") { 1 }, s.fetch(:qux, 0), s.fetch(:qux) { |k| k }] }
t(:fetch_err) { begin; s.fetch(:qux); rescue KeyError => e; [e.message, e.key, e.receiver.equal?(s)]; end }
s.kill; s.join
t(:hi_noblk) { Thread.handle_interrupt(RuntimeError => :immediate) }
t(:hi_bad) { Thread.handle_interrupt(RuntimeError => :xyzzy) {} }
t(:hi_arr) { Thread.handle_interrupt([]) {} }
t(:hi_nil) { Thread.handle_interrupt(nil) {} }
t(:uninit_start) { Class.new(Thread) { def initialize; end }.new.start }
t(:uninit_exit) { begin; Class.new(Thread) { def initialize; exit; end }.new; rescue ThreadError => e; e.class; end }
t(:uninit_raise) { Class.new(Thread) { def initialize; raise; end }.new }
t(:pending) { Class.new(Thread) { def initialize; pending = pending_interrupt?; super { pending }; end }.new.value }
t(:setname) { Class.new(Thread) { def initialize() self.name = "foo"; super; end }.new { Thread.current.name }.value }
class T2 < Thread
  def info = [name, alive?, status.class]
  def oops = nope
end
x = T2.new { sleep 0.05 }
x.name = "w"
t(:bare) { x.info }
x.join
t(:bare_unknown) { x.oops }
