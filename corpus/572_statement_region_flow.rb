$statement_effects = []
def statement_result
  $statement_effects << :first
  Class.new
  $statement_effects << :last
  Class.new { def answer; 42; end }
end
classes = 100.times.map { statement_result }
GC.start
p [classes.map { |c| c.new.answer }.uniq, $statement_effects.count(:first), $statement_effects.count(:last)]
def early_return
  begin
    Class.new
    return Module.new { def returned; :kept; end }
  ensure
    $statement_effects << :ensure
  end
end
m = early_return
GC.start
p [Object.new.extend(m).returned, $statement_effects.last]
p 3.times.map { |i| Class.new; next i + 10 }
p 3.times { Class.new; break [:break_value, Module.new.class] }
begin
  Class.new
  raise "statement error"
rescue RuntimeError => e
  p e.message
end
lines = []
TracePoint.new(:line) { |t| lines << t.lineno if t.path == __FILE__ }.enable do
  result = Module.new
  p result.class
end
p !lines.empty?
