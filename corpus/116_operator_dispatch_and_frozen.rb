# Operators are methods, and that stays true when the class is a builtin one:
# `!`, `===` and `!=` all have to consult the method table before falling back
# to the primitive.
class Symbol
  def ===(other)
    true
  end
end
def which(arg)
  case arg
  when :b then :matched_symbol
  when 4 then :matched_int
  end
end
p which(4)

class TrueClass
  def !
    :bang
  end
end
p [!true, !false, !nil, !1]

# `!=` is `==` negated, so redefining only `==` is enough
class Eq
  def ==(o); true; end
end
p [Eq.new == 1, Eq.new != 1]
class MyString < String
  def ==(b)
    "#{self}_" == b
  end
end
ma = MyString.new("a")
p [ma == "a", ma != "a_", "a_" == ma, "a" != ma, ma != MyString.new("a_"), ma == ma]

# +@ on a frozen string is an unfrozen copy; on an unfrozen one it is the
# receiver itself. -@ is the inverse. to_s answers the receiver, not a copy.
s = "foo".freeze
u = +s
p [u.equal?(s), u.frozen?, s.frozen?, (-s).frozen?, (+"y").frozen?]
t = "z"
p [t.to_s.equal?(t), t.dup.equal?(t), (+t).equal?(t)]
p [MyString.new("a").to_s.class, "a".to_s.class]
p [+1, -1, +1.5, -1.5, +(2 ** 70), -(2 ** 70)]

# freezing an object seals its instance variables too
class Sealed
  attr_accessor :bar
  def initialize
    @bar = 1
    freeze
  end
end
sealed = Sealed.new
begin
  sealed.bar = 2
rescue FrozenError => e
  p [:writer, e.class]
end
begin
  sealed.instance_variable_set(:@bar, 3)
rescue FrozenError => e
  p [:ivar_set, e.class]
end
p sealed.bar

# a proc's `return` returns from the method that DEFINED it, even when the
# call happens inside a lambda that has a return boundary of its own
$trace = :start
def through_lambda
  lambda { |pr| $trace = :in_lambda; pr.call; $trace = :lambda_continued }.call(Proc.new { return })
  $trace = :method_continued
end
through_lambda
p $trace

def lambda_returns_from_itself
  l = lambda { return :from_lambda }
  [l.call, :method_continued]
end
p lambda_returns_from_itself

# `lines(chomp: true)`, and the explicit bracket-setter call form
p ["a\nb".lines, "a\nb".lines(chomp: true), "a\nb\n".lines(chomp: true)]
arr = [1, 2, 3]
arr.[]=(1, 9)
p [arr, arr.[](1)]

# class_exec / module_exec take the same block a class body would
Widget = Class.new
Widget.class_exec { def hi; :hi; end }
p [Widget.new.hi, Widget.respond_to?(:module_eval), Widget.module_exec { 5 }]

# `@x ||= v` is a read that MAY write: when the short circuit already decides,
# there is no write at all -- which is what lets a memo be read on a frozen
# object (rubygems' Gem::Version does exactly this).
class Memo
  def initialize
    @computed = 0
    @value = :precomputed
    freeze
  end
  attr_reader :computed
  def value; @value ||= :late; end
  def missing; @missing ||= :late; end
  def andeq; @value &&= :replaced; end
end
memo = Memo.new
p memo.value
begin
  memo.missing
rescue FrozenError => e
  p [:missing, e.class]
end
begin
  memo.andeq
rescue FrozenError => e
  p [:andeq, e.class]
end
