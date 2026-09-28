# Thread#backtrace, #backtrace_locations and Thread.each_caller_location did
# not exist, and Kernel#caller took a negative level or length as a shorter
# list where ruby refuses it. The current thread's backtrace is caller(0)'s
# frames under one for the call itself; a dead thread's is nil.
def frames
  bt = Thread.current.backtrace
  p bt[0].sub(/\A.*?:/, ""), bt.size == caller(0).size + 1, bt[1].sub(/\A.*?:/, "")
  p Thread.current.backtrace_locations(0, 1).map { |l| [l.class, l.label] }
  p Thread.current.backtrace(1, 1) == caller(0, 1), Thread.current.backtrace(100)
  seen = []
  p Thread.each_caller_location { |l| seen << l.to_s }
  p seen == caller_locations.map(&:to_s)
  p Thread.each_caller_location { |l| break l.class }
  p((Thread.each_caller_location rescue $!))
  p((Thread.each_caller_location(1, foo: 2) {} rescue $!))
  p((caller(-1) rescue $!), (caller(0, -1) rescue $!))
  p((Thread.current.backtrace(-1) rescue $!), (Thread.current.backtrace_locations(0, -1) rescue $!))
end
frames
t = Thread.new {}
t.join
p t.backtrace, t.backtrace_locations
