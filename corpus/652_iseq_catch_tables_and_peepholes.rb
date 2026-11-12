# Round 31 of note 548: RubyVM::InstructionSequence's catch table -- a
# block's break, next and return thrown out of it, rescue / else / ensure
# with their sequences, a rescue modifier and retry -- and super, zsuper,
# defined?, lambdas, multiple assignment, and compile.c's peephole rules
# (opt_ary_freeze, opt_newarray_send, opt_duparray_send, newarray +
# expandarray, opt_neq with its two calldatas).
def show(src)
  iseq = RubyVM::InstructionSequence.compile(src, "<w>", "<w>", 1)
  puts iseq.disasm
  p iseq.to_a[12], iseq.to_a.last
end

show(<<~RUBY)
  [1, 2].each do |x|
    next if x == 1
    break x
  end
  def m = [1].each { |a| return a }
RUBY

show(<<~RUBY)
  begin
    x = 1
  rescue ArgumentError, *[TypeError] => e
    retry if e
  else
    x = 2
  ensure
    x = 3
  end
  y = (raise rescue 4)
RUBY

show(<<~RUBY)
  class A < Object
    def m(a, *r, k: 1)
      super
      super(a) { |z| z }
      defined?(super) && defined?(a.b.c) && defined?(@v)
    end
  end
RUBY

show(<<~RUBY)
  f = ->(q) { q }
  a, (b, c), *d = 1, [2, 3], 4
  h = {}
  h[:k], o = 5, 6
  [1, 2].freeze
  {k: 1}.freeze
  [a, b].max
  [1, 2].include?(a)
  a != b
RUBY
