# `raise Cls, obj` makes the exception with `Cls.exception(obj)`, whatever
# obj is, and a Hash is no exception to that: `raise ArgumentError, {a: 1}`
# and `raise ArgumentError, h` have the message "{a: 1}". Keywords that are
# not `cause:` are that Hash too.
#
# Here a Hash in that place was taken for keywords and dropped, and the
# message was the class's name. A `case / in` over a Hash that no branch
# matches raises NoMatchingPatternError with the value as its message, so on
# the ISeq VM, which raises it as ruby's instructions do, the message of
# such a case was "NoMatchingPatternError".
def t
  yield
  :none
rescue Exception => e
  [e.class, e.message, e.cause.class]
end
h = {a: "s"}
p t { raise ArgumentError, h }
p t { raise ArgumentError, {a: "s"} }
p t { raise(ArgumentError, h) }
p t { raise ArgumentError, {} }
p t { raise ArgumentError, [1] }
p t { raise ArgumentError, h, [] }
p t { raise ArgumentError.new(h) }
p t { fail ArgumentError, h }
p t { raise h }
# keywords: `cause:` is raise's own, the others are the message
p t { raise ArgumentError, foo: 1 }
p t { raise ArgumentError, **{} }
p t { raise ArgumentError, "m", cause: nil }
p t { raise ArgumentError, cause: RuntimeError.new("c") }
p t { raise ArgumentError, {a: Object}, cause: nil }
p t { raise ArgumentError, {a: 1}, cause: KeyError.new("k") }
# a class with an #initialize of its own is given the Hash
class E822 < StandardError
  def initialize(x = :none) = super("got #{x.inspect}")
end
p t { raise E822, {a: 1} }
p t { raise E822, b: 2 }
p t { raise E822 }

# what a `case / in` raises when no branch matches
def pick(v)
  case v
  in {a: Integer => y} then [:one, y]
  in {b: z} then [:two, z]
  in [Integer => w] then [:three, w]
  end
rescue NoMatchingPatternError => e
  [e.class, e.message]
end
p pick({a: 1}), pick({a: "s"}), pick({}), pick(5), pick(["s"]), pick([1, 2]), pick(nil), pick({a: {b: [1]}})
# ...the value's #to_s, as any raise's message is: not its inspect
o822 = Object.new
def o822.to_s = "an object's to_s"
def o822.inspect = "an object's inspect"
p pick("a string"), pick(:sym), pick(1.5), pick(1..2), pick(true), pick(o822), pick(Object), pick("")
def pick1(v)
  case v
  in {a: Integer => y} then y
  end
rescue NoMatchingPatternError => e
  [e.class, e.message]
end
p pick1({a: "s"}), pick1({}), pick1(:sym)
