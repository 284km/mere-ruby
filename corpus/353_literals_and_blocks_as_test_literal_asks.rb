# Literals and block arguments as test_literal and test_proc ask (note 377):
# a leading-zero octal with an 8 or a 9 is a SyntaxError and `0_10` is octal;
# `?\u{201c}` is a character literal, in an eval'd EUC-JP source too; `yield
# *a, **h`, `super *a` and `super &b` take their paren-less splats; the
# frozen_string_literal compile options of RubyVM::InstructionSequence; a
# block given keywords that came to nothing (`**{}`) does not spread one
# Array over optional parameters; attr_* methods know where they were
# declared; and `it = ...` in a block makes `it` a local.
%w[09 0_9 019 08.5 0_10 017 00_1].each do |s|
  r = begin; eval(s); rescue SyntaxError; :syntax_error; end
  p [s, r]
end
p %w[0_0 0_1 0_7 0_9 0__1].map { |s| Integer(s) rescue :err }
p ?\u{201c}, ?\u{41}
x = eval(%[?\\\u{201c}].encode("euc-jp"))
p [x.encoding, x.bytes]
y = eval(%[?あ].encode("euc-jp"))
p [y.encoding, y.bytes]

class A353
  def m(*a, **k, &b) = [a, k, b&.call]
end
class B353 < A353
  def m(*a, **k); super *a, **k; end
end
class C353 < A353
  def m(b); super &b; end
end
p B353.new.m(1, 2, x: 3), C353.new.m(-> { :blk })
def y353(*a, **k); yield *a, **k; end
p y353(1, z: 2) { |a, **k| [a, k] }
def h353(h); yield **h; end
p h353({q: 1}) { |**k| k }

opt = {frozen_string_literal: true, debug_frozen_string_literal: true}
s = RubyVM::InstructionSequence.compile('_="foo-1"', "test.rb", "test.rb", 1, **opt).eval
p s.frozen?
begin; s << "x"; rescue FrozenError => e; p e.message; end
p RubyVM::InstructionSequence.compile('"a"').eval.frozen?
p RubyVM::InstructionSequence.compile("# frozen_string_literal: false\n'a'", frozen_string_literal: true).eval.frozen?
t = "x"
begin; t.freeze << "y"; rescue FrozenError => e; p e.message; end

def a353(arg, kw)
  yield arg, **kw
end
a353([1, 2, 3], {}) { |x, y = 0| p [x, y] }
a353([1, 2, 3], {}) { |x, y| p [x, y] }
a353([1, 2, 3], {}) { |x, y = 0, **k| p [x, y, k] }
pr = proc { |x, y = 0| [x, y] }
p pr.call([1, 2, 3], **{}), pr.call([1, 2, 3])
def yielder353(s) = yield(*s)
p yielder353([[:a, :b], Hash.ruby2_keywords_hash({})]) { |a, b, **| [a, b] }
p yielder353([[:a, :b], Hash.ruby2_keywords_hash({})]) { |a, b| [a, b] }
p yielder353([[:a, :b], {}]) { |a, b, **| [a, b] }

class D353
  attr_reader :r
  attr_accessor :w
end
p D353.instance_method(:r).source_location[1], D353.instance_method(:w=).source_location[1]
p D353.new.method(:r).inspect.end_with?(":#{D353.instance_method(:r).source_location[1]}>")
def z353; end
p method(:z353).to_proc.binding.source_location[1]
q = proc {}
p q.binding.source_location[1] == __LINE__ - 1
"foo".tap do
  it = it = "bar"
  p binding.local_variables, binding.implicit_parameters, it
end
"foo".tap { p it, binding.implicit_parameters }
# (read first and then assigned: the parameter and, from there on, the local)
"foo".tap do
  it or raise
  it = it = "bar"
  p binding.implicit_parameters, binding.implicit_parameter_get(:it), binding.local_variables, it
end
