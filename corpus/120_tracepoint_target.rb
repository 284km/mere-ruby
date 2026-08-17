# TracePoint#enable(target:) narrows a tracepoint to one method. Before, #enable
# took no arguments at all, so the keyword was an ArgumentError and four
# bootstraptest pairs died on that rather than on anything about tracing.
def watched; 1; end
def other;   2; end

seen = []
tp = TracePoint.new(:call) { |t| seen << t.method_id }
tp.enable(target: method(:watched))
watched
other
watched
tp.disable
p seen

# without a target, every call is seen
seen2 = []
tp2 = TracePoint.new(:call) { |t| seen2 << t.method_id }
tp2.enable
watched
other
tp2.disable
p seen2

# the block form enables for the duration of the block
seen3 = []
tp3 = TracePoint.new(:call) { |t| seen3 << t.method_id }
tp3.enable(target: method(:other)) do
  watched
  other
end
p seen3
p tp3.enabled?
other
p seen3
