# Queue#pop / SizedQueue#push take `timeout:` as a keyword -- `timeout: nil`
# is still the keyword, not a truthy non_block argument -- and refuse a
# timeout that is not a number before anything waits. A non-blocking pop of a
# closed empty queue raises; a blocking one answers nil.
q = Queue.new
q << 1
p q.pop(timeout: nil)
t = Thread.new { q.pop(timeout: nil) }
Thread.pass until t.status == "sleep"
q << 2
p t.value
p Queue.new.pop(timeout: 0.001)
["1", true, false, :x].each do |v|
  begin
    Queue.new.pop(timeout: v)
  rescue TypeError => e
    p [v, e.message]
  end
end
begin
  Queue.new.pop(true, timeout: 1)
rescue ArgumentError => e
  p e.message
end
c = Queue.new
c.close
p c.pop
begin
  c.pop(true)
rescue ThreadError => e
  p e.message
end
s = SizedQueue.new(1)
s << 1
p s.push(2, timeout: 0.001)
begin
  s.push(2, timeout: "x")
rescue TypeError => e
  p e.message
end
