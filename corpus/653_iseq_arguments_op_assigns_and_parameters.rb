# Round 32 of note 548: RubyVM::InstructionSequence's compiler takes every
# call argument shape (keyword hashes with any key and **, several splats,
# a splat with keywords, *, ** and & passed on, ...), the op-assigns on
# globals, constants, constant paths, calls and indexes, alias, undef,
# backticks, and destructured, `...` and checkkeyword parameters.
def show(src)
  iseq = RubyVM::InstructionSequence.compile(src, "<w>", "<w>", 1)
  puts iseq.disasm
  p iseq.to_a.last
end

show(<<~RUBY)
  def m(*, **, &) = f(*, **, &)
  def n(...) = g(1, ...)
  f("k" => 1, **h, a: 2)
  f(*a, *b, k: 1, &blk)
  f(*a, **h)
RUBY

show(<<~RUBY)
  $g ||= 1
  C ||= 2
  A::B &&= 3
  o.x += 4
  o&.y ||= 5
  h[1, *r] += 6
  h[:k] ||= 7
  alias foo bar
  alias $new $old
  undef foo, bar
  `ls \#{x}`
RUBY

show(<<~RUBY)
  def m((a, *b), c, k: c + 1)
    [1].each { |(x, y), z| x }
  end
RUBY
