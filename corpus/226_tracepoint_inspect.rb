# TracePoint#inspect printed the object's ivars (@events, @blk, ...). It is
# ruby's format now: outside the handler only whether it is enabled, and
# inside it the event and where it happened.
tp = TracePoint.new(:line) { }
p tp.inspect
tp.enable
p tp.inspect
tp.disable
p tp.to_s.start_with?("#<TracePoint:0x")
seen = []
TracePoint.new(:line) { |t| seen << t.inspect.sub(__FILE__, "FILE") }.enable do
  x = 1
end
p seen
calls = []
def traced = 42
TracePoint.new(:call) { |t| calls << t.inspect.sub(__FILE__, "FILE").sub(/:\d+>\z/, ">") }.enable do
  traced
end
p calls
