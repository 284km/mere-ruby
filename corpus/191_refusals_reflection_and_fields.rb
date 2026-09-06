# What a method REFUSES is part of what it is. So is the name it answers to,
# and what the exception it raises carries.

# --- the count of arguments -------------------------------------------------
def refusal
  yield
  :no_refusal
rescue ArgumentError => e
  e.message
end
p refusal { [1, 2].first(1, 2) }
p refusal { 1.gcd }
p refusal { 3.clamp(1, 2, 3) }
p refusal { 1.to_r(1) }
p refusal { [1, 2].each_slice }
p refusal { [1, 2].each_slice(2, 2) { } }
p refusal { "abc".sub("a") { "z" } }        # a block CHANGES the bounds
p refusal { [1, 2].first(1) }
p refusal { {a: 1}.replace(b: 2) }          # a `k: v` hash is one argument
p refusal { 1.234.round(2, half: :up) }     # ...or none, and both must pass

class Countable
  include Enumerable
  def each; yield 1; yield 2; yield 3; end
end
p refusal { Countable.new.all?(1, 2) }      # the bounds are Enumerable's
p refusal { Countable.new.take }

# a size below one is refused before anything is built
p refusal { [1, 2].each_slice(0).to_a }
p refusal { [1, 2].each_cons(0).to_a }

# --- one method, two names --------------------------------------------------
p Enumerable.instance_method(:collect) == Enumerable.instance_method(:map)
p Enumerable.instance_method(:member?) == Enumerable.instance_method(:include?)
p Symbol.instance_method(:next) == Symbol.instance_method(:succ)
p Symbol.instance_method(:id2name) == Symbol.instance_method(:to_s)
p Regexp.method(:escape) == Regexp.method(:quote)
Pair = Struct.new(:a, :b)
p Pair.instance_method(:inspect) == Pair.instance_method(:to_s)
p Pair.instance_method(:deconstruct) == Pair.instance_method(:to_a)
n = 7
p n.method(:then) == n.method(:yield_self)
p Object.new.respond_to?(:then)

# --- an Enumerable of one's own ---------------------------------------------
class Pairs
  include Enumerable
  def each(*args)
    p [:each_got, args] unless args.empty?
    yield [:a, 1]
    yield [:b, 2]
    yield [:a, 3]
  end
end
p Pairs.new.to_h                             # a repeated key is ONE entry
p Pairs.new.to_a(:passed, :through)
p Countable.new.each_slice(2).to_a
p Countable.new.each_cons(2).to_a
p Countable.new.chunk { |x| x.odd? }.to_a
p Countable.new.each_slice(2) { |g| p g }.class

# --- def on whatever an expression answers ----------------------------------
def (@matcher = Object.new).===(x)
  x.odd?
end
p [1, 2, 3].grep(@matcher)
target = Object.new
def (target).describe = "described"
p target.describe

# --- what an exception carries ----------------------------------------------
begin
  {a: 1}.fetch(:missing)
rescue KeyError => e
  p [e.key, e.receiver]
end
begin
  Object.new.no_such_method(1, 2)
rescue NoMethodError => e
  p [e.name, e.args, e.receiver.class]
end
begin
  "frozen".freeze << "!"
rescue FrozenError => e
  p e.receiver
end
begin
  throw :label, 42
rescue UncaughtThrowError => e
  p [e.tag, e.value]
end
begin
  def needs_block; yield; end
  needs_block
rescue LocalJumpError => e
  p e.reason
end
p Errno::EINVAL.new.errno == Errno::EINVAL::Errno
p Errno::EINVAL.new("custom message", "location").message
p SystemCallError.new("m", Errno::ENOENT::Errno).class

# --- a pattern describes itself ---------------------------------------------
p [/x/i.casefold?, /x/.casefold?]
p [/x/.fixed_encoding?, /x/n.fixed_encoding?]
p [Regexp.linear_time?(/x*/), Regexp.linear_time?(/(a)\1/)]
p [Regexp.try_convert(/x/), Regexp.try_convert("x")]
p Regexp.timeout
p [/x/.hash == /x/.hash, /x/i.hash == /x/.hash]
p [/x/n.inspect, /x/.source.encoding.to_s, Regexp.quote("ab").encoding.to_s]
p (/x/ === :x)
matchable = Object.new
def matchable.to_str = "x"
p (/x/ === matchable)
begin
  /x/.match(Object.new)
rescue TypeError => e
  p e.message
end
