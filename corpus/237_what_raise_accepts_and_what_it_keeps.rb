# What `raise` accepts, what it refuses, and what an exception keeps across a
# second raise: its cause (unless that would make a loop), a backtrace set to
# nil being none, a backtrace given as Locations, and the #exception /
# #set_backtrace a class defines for itself -- in this thread and across one.
def show
  yield
rescue Exception => e
  p [e.class, e.message]
end

[true, false, nil, 3, :s].each { |v| show { raise v } }
show { raise "a", "b" }
show { raise String }
anon = Class.new(StandardError)
show { raise anon rescue p($!.message =~ /\A#<Class:0x\h+>\z/); raise }

begin
  raise "Error 1"
rescue => e1
  begin
    raise "Error 2"
  rescue => e2
    begin; raise e1, cause: e2; rescue => x; p [x.class, x.message]; end
    begin; raise e1; rescue => y; p [y == e1, y.cause]; end
  end
end
begin; begin; raise "first"; rescue; raise "second", cause: nil; end; rescue => z; p z.cause; end
begin; begin; raise "first"; rescue; foo_undefined; end; rescue NameError => n; p n.cause&.message; end

begin; raise "raised"; rescue => ex; end
ex.set_backtrace(nil)
begin; raise ex; rescue => r; p r == ex, r.backtrace.size; end

def locs = caller_locations(0, 2)
l2 = locs
begin; raise ArgumentError, "m", l2; rescue => e; p e.backtrace_locations.map(&:to_s) == l2.map(&:to_s), e.backtrace.size; end
err = RuntimeError.new("s")
p err.set_backtrace("one line"), err.backtrace_locations
[[:sym], ["ok", nil], ["ok", ["nested"]], :sym].each { |b| show { RuntimeError.new.set_backtrace(b) } }
p StandardError.exception("via .exception").message

logged = Class.new(Exception) do
  attr_accessor :log
  def initialize(*a) = (@log = []; super)
  def exception(*a) = (@log << [:exception, a.size]; super)
  def set_backtrace(bt) = (@log << [:set_backtrace, bt]; super)
end
x = logged.new
begin; raise x, "m", ["a.rb:1"]; rescue Exception => r; p r.message, r.backtrace, x.log; end

t = Thread.new { Thread.current.report_on_exception = false; sleep }
Thread.pass until t.stop?
p t.backtrace.map { |l| l[/'.*'/] }
t.raise(ArgumentError, "into a sleeping thread")
begin; t.join; rescue => e; p e.message, e.backtrace.map { |l| l[/'.*'/] }; end

o = Object.new
class << o; public :raise; end
show { o.raise "public raise" }
show { o.raise(TypeError, "with a block") { :ignored } }
p o.respond_to?(:raise), Object.new.respond_to?(:raise)
