# TracePoint after sweep469: a method define_method made is a block as well
# -- :b_call after its :call and :b_return before its :return (also when a
# raise or a return from a block leaves it) -- and a Struct member's writer
# is a C method (:c_call / :c_return, with the alias it was called by).

class C
  define_method(:dm) { |x| x + 1 }
  define_method(:dr) { return 5 }
  define_method(:dx) { raise "no" }
end
o = C.new
ev = []
TracePoint.new(:call, :return, :b_call, :b_return) do |t|
  next unless t.defined_class == C
  ev << [t.event, t.method_id, (t.return_value if t.event == :return || t.event == :b_return)]
end.enable do
  o.dm(1)
  o.dr
  (o.dx rescue nil)
end
ev.each { |e| p e }

S = Struct.new(:x) do
  alias y= x=
end
s = S.new
m = s.method(:x=)
sev = []
TracePoint.new(:c_call, :c_return, :call, :return) do |t|
  next if t.method_id == :call
  sev << [t.event, t.method_id, t.callee_id, (t.return_value if t.event == :c_return)] if t.method_id == :x=
end.enable do
  s.x = 1
  s.y = 2
  m.call(3)
end
sev.each { |e| p e }
