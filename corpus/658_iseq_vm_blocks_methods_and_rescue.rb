# Rounds 34-36 of note 548 (note 552): the ISeq VM runs a sequence's blocks,
# the methods and classes it defines, and its rescue / ensure regions -- a
# block's, a method's and a class body's sequence each a program of its own,
# run in the frame the evaluator makes for it. The answers are ruby's
# whether the VM runs the sequence or refuses it for the evaluator.
def ev(src) = RubyVM::InstructionSequence.compile(src).eval

# blocks: parameters of every shape, closures, break / next / redo, procs
p ev("x = 5\n[1, 2].each { |a; t| t = a + x; x = t }\nx")
p ev("[[1, [2, 3]], [4, [5, 6]]].map { |a, (b, c)| a + b + c }")
p ev("pr = proc { |a, b = (a * 2), *r, k: 3, **o| [a, b, r, k, o] }\n[pr.call(1), pr.call(1, 2, 3, k: 4, z: 5)]")
p ev("[[1, 2], [3, 4]].map { _1 + _2 } + [1, 2].map { it * 3 }")
p ev("[1, 2, 3].each { |v| break v * 10 if v == 2 }")
p ev("i = 0\nr = [1, 2].each { |v| i += 1; redo if i == 1 }\n[r, i]")
p ev("f = ->(a, b = 2) { a + b }\n[f.(1), f[3, 4], f.lambda?, f.arity, f.parameters]")
p ev("g = proc { |a, (b, c), d| }\n[g.arity, g.parameters]")
p ev("x = 1\nmk = proc { x = 2; y = 3; proc { y += x } }\ninner = mk.call\n[inner.call, inner.call, x]")
p ev("r = []\nfor v in [1, 2, 3]\n  r << v * 2\nend\n[r, v]")
p ev("x = 42\ny = Ractor.shareable_lambda { x }\ny.call")
p ev("%w[a b].map(&:upcase) + [1, 2].map(&proc { |v| v + 1 })")

# methods and classes: parameters, yield, super, visibility, alias / undef
p ev("def opt(a, b = a * 2, *r, k:, o: 2, **z, &blk) = [a, b, r, k, o, z, blk&.call]\n[opt(1, k: 0), opt(1, nil, 3, k: 4, o: 5, q: 6) { 7 }]")
p ev("def twice\n  return to_enum(:twice) unless block_given?\n  yield 1\n  yield 2, 3\nend\nr = []\ntwice { |a, b| r << [a, b] }\n[r, twice.to_a]")
p ev(<<~'SRC')
  class WBase
    def initialize(n) = @n = n
    def hi(a = 1) = "base#{a}:#{@n}"
    def self.make(*a) = new(*a)
  end
  class WKid < WBase
    def hi(a = 2) = "kid+" + super
    def bye = hi(3)
    private
    def hidden = 1
    public
    alias greeting hi
    def gone = 2
    undef gone
    class << self
      def cm = :cm
    end
    LIMIT = 9
  end
  k = WKid.make(7)
  [k.hi, k.bye, k.greeting(5), WKid.cm, WKid::LIMIT, k.respond_to?(:gone),
   WKid.private_instance_methods(false), WBase.private_instance_methods(false)]
SRC
p ev("module WGreet\n  def greet = \"hi \#{name}\"\nend\nclass WPerson\n  include WGreet\n  attr_accessor :name\n  def initialize(n) = @name = n\nend\nq = WPerson.new('al')\nq.name = 'bo'\n[q.greet, WPerson.include?(WGreet)]")
p ev("o = Object.new\ndef o.single(a) = a * 2\nclass << o\n  def other = :o\nend\n[o.single(4), o.other, o.singleton_methods.sort]")

# rescue, ensure, retry; a jump out of a rescue clause through an ensure
p ev("x = begin\n  Integer('zz')\nrescue TypeError\n  :type\nrescue ArgumentError, IndexError => e\n  [:arg, e.class]\nelse\n  :none\nensure\n  $w1 = :done\nend\n[x, $w1, $!]")
p ev("n = 0\nbegin\n  n += 1\n  raise 'again' if n < 3\n  n\nrescue\n  retry\nend")
p ev("def ord(r)\n  r << :body\n  return r\nensure\n  r << :ensure\nend\nord([])")
p ev("out = []\n[1, 2, 3].each do |v|\n  begin\n    next if v == 1\n    break if v == 3\n    out << v\n  ensure\n    out << :e\n  end\nend\nout")
p ev("i = 0\nacc = []\nwhile i < 4\n  i += 1\n  begin\n    raise 'skip' if i.even?\n    acc << i\n  rescue\n    next\n  ensure\n    acc << :e\n  end\nend\nacc")
p ev("e1 = nil\nbegin\n  begin\n    raise 'first'\n  rescue => e1\n    raise TypeError, 'second'\n  end\nrescue => e2\n  [e1.message, e2.message, e2.cause.equal?(e1)]\nend")
p ev("r = catch(:found) do\n  begin\n    throw :found, 42\n  ensure\n    $w2 = :ensured\n  end\nend\n[r, $w2]")
begin
  ev("def strict(a, b) = a\nstrict(1)")
rescue ArgumentError => e
  p e.message
end
# (a def run as a statement keeps the initializers private, as a class
#  body's own def does)
class WIni; eval("def initialize; end"); if true; def initialize_copy(o); end; end; end
p WIni.private_instance_methods(false).sort
