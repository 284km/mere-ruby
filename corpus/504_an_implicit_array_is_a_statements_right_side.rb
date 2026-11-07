# `x = *b` (parse.y's mrhs) stands as a statement's right side only: as a
# condition, an argument, a flow keyword's value or another assignment's
# value it is "multiple assignment is not allowed in this context"
# (test/prism's implicit_array_test). A scoped constant takes one too. And
# an explicit `o.[]=(0, 1)` is a call, answering what the method answers,
# where `o[0] = 1` answers 1 (attribute_write_test).
$VERBOSE = nil
def refused?(src)
  RubyVM::InstructionSequence.compile(src)
  false
rescue SyntaxError
  true
end
b = [1, 2]
module A; end
a = *b
A::A = *b
A::B = 3, 4
::C = *b
p a, A::A, A::B, C
x = (y = *b)
p x, y
o = Struct.new(:a).new
o.a = *b
p o.a
[
  "if a = *b then end", "if o.a = *b then end", "if $a = *b then end", "unless @a = *b then end",
  "while a = *b do end", "x while a = *b", "foo(a = *b)", "foo a = *b", "return a = *b", "break a = *b",
  "if a = 1, 2 then end", "if A::A = *b then end", "if a, b = *c then end",
  "a = *b", "x = (a = *b)", "p(a = [*b])", "if a = [*b] then end", "x = *b, 1", "A::A = 1, 2", "return *b", "a, b = *c",
].each { |src| puts "#{src.inspect}: #{refused?(src) ? 'refused' : 'ok'}" }
class T
  def self.[]=(a, b)
    :ret
  end
end
p T.[]=(0, 1), (T[0] = 1), (T.[]=(0, 1) { })
