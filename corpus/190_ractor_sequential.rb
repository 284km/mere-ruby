# Ractor, as this interpreter can model it: one thread of control, so a ractor
# keeps its block and runs it the moment someone needs what it produces. What
# a program can OBSERVE of that -- the object, its name, its value, the
# mailbox, the ports, select, the refusals -- is what ruby prints too.

r = Ractor.new { 6 * 7 }
p r.class
p r.value
p r.value                      # the body runs once; the value is kept

named = Ractor.new(name: "worker") { :done }
p named.name
p named.value
p Ractor.new { 1 }.name

# arguments reach the block, and a message sent before the body asks for it is
# in the mailbox when it does.
p Ractor.new(2, 3) { |a, b| a * b }.value
mailed = Ractor.new { Ractor.receive + Ractor.receive }
mailed.send(10)
mailed << 32
p mailed.value

# a terminated ractor takes no more messages: its port is closed.
done = Ractor.new { :ok }
done.join
p done.default_port.closed?
begin
  done.send(:late)
rescue Ractor::ClosedError => e
  p [e.class, e.message]
end

# an exception in the body is re-raised on the asking side, wrapped, with the
# original as its cause.
boom = Ractor.new { raise ArgumentError, "inside" }
begin
  boom.value
rescue Ractor::RemoteError => e
  p [e.class, e.cause.class, e.cause.message]
end

# ports carry values out of a body without asking for its value.
ports = 3.times.map { Ractor::Port.new }
Ractor.new(ports) { |ps| ps[0] << :a; ps[1] << :b; ps[2] << :c }
p ports[1].receive
p ports[0].receive
p ports[2].receive
port = Ractor::Port.new
port.close
p port.closed?
begin
  port << 1
rescue Ractor::ClosedError => e
  p e.class
end

# select answers the first argument that has something for you.
rs = 3.times.map { |i| Ractor.new(i) { |n| "r" + n.to_s } }
picked = []
3.times do
  got, obj = Ractor.select(*rs)
  picked << obj
  rs.delete(got)
end
p picked.sort

# a Ractor cannot be allocated or copied: it IS its block.
begin
  Ractor.allocate
rescue TypeError => e
  p e.message
end
begin
  Ractor.new {}.dup
rescue TypeError => e
  p e.message
end
begin
  Ractor.new
rescue ArgumentError => e
  p e.message
end
begin
  Ractor.new(name: 1) {}
rescue TypeError => e
  p e.message
end

p Ractor.main.class
p Ractor.current.equal?(Ractor.main)
p Ractor.count.class
p Ractor.shareable?(:sym)
p Ractor.shareable?([1, 2])
p Ractor.make_shareable("str").frozen?

# a monitoring port hears :exited when the body finishes.
watch = Ractor::Port.new
job = Ractor.new { :finished }
job.monitor(watch)
job.join
p watch.receive
p Ractor.main?

# ractor-local storage, read through the ractor or through the class.
Ractor[:tries] = 1
p Ractor[:tries]
p Ractor.current[:tries]
p Ractor.store_if_absent(:tries) { 99 }
p Ractor.store_if_absent(:fresh) { 5 }
