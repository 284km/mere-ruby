# A statement that STARTS with one of the parser's statement-leading names --
# extend, include, require, private -- and continues with a `.` is a call on a
# receiver, not that statement form. `extend.get` on a local named `extend` was
# an "unexpected token: ." because the parser committed to `extend M` and then
# met a dot it had no rule for. `private` already had the guard; the others did
# not.
class E
  def get; 7; end
end
extend = E.new
extend.get
p extend.get

include = E.new
p include.get

require = E.new
p require.get

# rescue takes an EXPRESSION, not only a constant, and Ruby evaluates it: a
# constant followed by a `.` used to stop at the constant and leave the `.new`
# for the caller, which said "expected end of statement". What the expression
# has to evaluate TO is a class or module -- anything else is a TypeError, which
# is the behaviour the bootstraptest pair was checking for.
class Matcher
  def ===(o); o.is_a?(RuntimeError); end
end
begin
  begin
    raise "boom"
  rescue Matcher.new
    p :never
  end
rescue TypeError => e
  p e.message
end

# an expression that DOES evaluate to a class works
def picker; RuntimeError; end
begin
  raise "boom"
rescue picker
  p :caught
end

module M; Err = ArgumentError; end
begin
  raise ArgumentError, "arg"
rescue M::Err => e
  p e.message
end

# A rescue clause names a CONSTANT, and a constant can hold a class under
# another name. Matching the written name against the exception's class name
# missed both of these -- the raise worked, the rescue did not, and the program
# died with the exception it had just written a handler for.
Err = Class.new(StandardError)          # how most gems declare one
begin
  raise Err, "made"
rescue Err => e
  p e.message
end

Alias = ArgumentError                    # a plain alias
begin
  raise ArgumentError, "aliased"
rescue Alias => e
  p e.message
end

module N; Scoped = TypeError; end        # and a scoped one
begin
  raise TypeError, "scoped"
rescue N::Scoped => e
  p e.message
end
