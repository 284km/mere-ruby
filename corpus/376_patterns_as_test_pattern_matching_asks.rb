# Pattern matching as test_pattern_matching asks: a pin's group across lines,
# the keys `{**}` asks deconstruct_keys for, a refined `===` in a constant
# pattern, and the refusals of a range of names and of misplaced labels

r = 1 in ^(1
)
p r
t = 1 in ^(1
)
p t
1 in ^(1
)
x = 2
case 3
in ^(x +
  1) then p :pinned
end

class C
  class << self; attr_accessor :keys; end
  def initialize(h) = @h = h
  def deconstruct_keys(keys) = (C.keys = keys; @h)
end
[
  -> { case C.new({a: 0}); in {**}; end },
  -> { case C.new({a: 0}); in {a: 0, **r}; end },
  -> { case C.new({a: 0}); in {a: 0, **}; end },
  -> { case C.new({a: 0}); in {a: 0, **nil}; end },
  -> { case C.new({a: 0}); in {}; else; end },
].each { |f| f.call; p C.keys }

class C1; end
class C2; end
module M
  refine C2.singleton_class do
    def ===(obj) = obj.kind_of?(C1)
  end
  refine Hash do
    def deconstruct_keys(_) = {a: 0}
  end
end
using M
case C1.new
in C2 then p :refined_eqq
end
case({})
in {a: 0} then p :refined_keys
end

def refused(src)
  RubyVM::InstructionSequence.compile(src)
  :ok
rescue SyntaxError => e
  e.message.lines.map(&:chomp).grep(/unexpected|expected/).map { |l| l.sub(/\A.*?: /, "") }
end
[
  "case 0\nin a..b\nend",
  "case 0\nin a...b\nend",
  "case 0\nin __LINE__..5\nend",
  "case 0\nin a, b:\nend",
  "case 0\nin [a:]\nend",
  "case 0\nin {a}\nend",
  "case 0\nin {0 => a}\nend",
].each { |s| p [s, refused(s).is_a?(Array) ? refused(s).any? { _1.include?("unexpected") } : refused(s)] }

# (and a private_constant over an autoload not yet loaded: Bug #11055)
require 'tmpdir'
Dir.mktmpdir('autoload') do |dir|
  File.write(File.join(dir, "zzz_376.rb"), "class AutoloadTest376\n  ZZZ = :ZZZ\nend\n")
  $LOAD_PATH.unshift dir
  class AutoloadTest376
    autoload :ZZZ, "zzz_376.rb"
    private_constant :ZZZ
    p ZZZ
  end
  p((AutoloadTest376::ZZZ rescue $!.class))
  $LOAD_PATH.shift
end
