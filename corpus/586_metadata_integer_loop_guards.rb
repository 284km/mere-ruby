# Hoisted loop eligibility preserves captured locals, zero iterations and GC.
outer = nil
factory_line = __LINE__ + 1
factory = proc do
  outer = Module.new
  Class.new do
    include outer
  end
end
p 4.times(&factory)
p outer.class
saved = outer
p 0.times(&factory), (-2).times(&factory), outer.equal?(saved)
seen = []
trace = TracePoint.new(:b_call) do |event|
  seen << :call if event.path == __FILE__ && event.lineno == factory_line
end
trace.enable { 2.times(&factory) }
p seen
p Hash.new { :fresh_default }[:missing]
stress = GC.stress
GC.stress = true
p 3.times(&factory)
GC.stress = stress
p outer.class
GC.start
p Class.new { include outer }.ancestors.include?(outer)
