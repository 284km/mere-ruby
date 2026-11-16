# Round 37 of note 548 (note 552): a sequence the ISeq VM runs fires a
# TracePoint's events where ruby's own sequence does -- :line on each line
# event, :call / :return, :b_call / :b_return, :c_call / :c_return, :raise /
# :rescue, :class / :end -- and its lines are Coverage's while Coverage runs.
ev = []
tp = TracePoint.new(:line, :call, :return, :b_call, :b_return, :c_call, :c_return, :raise, :rescue, :class, :end) do |t|
  next unless t.path == "w659.rb"
  ev << [t.event, t.lineno, t.method_id]
end
src = <<'X'
def add(a, b)
  a + b
end
x = add(1, 2)
[1, 2].each do |v|
  x += v
end
class W659
  def m = 1
end
begin
  raise "a"
rescue => e
  y = 1
end
x
X
q = RubyVM::InstructionSequence.compile(src, "w659.rb")
r = nil
tp.enable { r = q.eval }
p r
ev.each { |e| p e }

require "coverage"
Coverage.setup(lines: true)
Coverage.resume
q = RubyVM::InstructionSequence.compile("a = 1\nif a > 0\n  b = 2\nelse\n  b = 3\nend\n3.times { a += 1 }\n[1].each do |v|\n  a += v\nend\n", "w659_cov.rb")
q.eval
p Coverage.result["w659_cov.rb"]
