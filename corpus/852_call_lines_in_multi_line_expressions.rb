# A call written on a later line than its statement runs on its own line,
# as ruby's frame reports it (the call node's line). The evaluator moved the
# line only at a statement, so `-> do ... end.call` reported the line of `->`
# and an argument on a line of its own reported the line of `foo(`.
# activesupport's backtrace_cleaner_test asks it of `-> do ... end.call`.
def here = caller_locations(1, 1)[0].lineno
def foo(*a, **k) = [a, k, here]
def m
  -> do
    caller(0, 2)[1][/\d+/].to_i
  end.call
end
p m
def k
  foo(
    1,
    caller(0, 1)[0][/:(\d+):/, 1].to_i
  )
end
p k
def m1
  foo(
    1,
    here
  )
end
p m1
def m2
  foo(1,
      2)
end
p m2
def m3
  foo(
    k: here,
    j: 2
  )
end
p m3
def m4
  [1, 2]
    .map { |x| x }
    .then { here }
end
p m4
def m5
  x = [
    here,
    here
  ]
  x
end
p m5
def m6
  foo(*[
    here
  ])
end
p m6
def m7
  -> {
    here
  }.call
end
p m7
def m8
  begin
    raise ArgumentError,
      "msg"
  rescue => e
    e.backtrace_locations[0].lineno
  end
end
p m8
def m10
  foo(bar = 1,
      here,
      bar)
end
p m10
def m11
  foo([1].map { |v|
        v
      }, here)
end
p m11
def m13
  foo(
    here, here
  ).last
end
p m13
# the same names as values, unchanged
def m14(a = 1)
  foo(
    a,
    defined?(
      a
    )
  )
end
p m14
class Bc
  def first = caller_locations(1, 1)[0].lineno
  def invoke
    -> do
      first.tap { @line = __LINE__ + 1 }
    end.call
  end
  attr_reader :line
end
b = Bc.new
p [b.invoke, b.line]

# (review of #180) defined? looks through the line marks on arguments, keyword
# values and elements: none of them is called, and the answer is ruby's
$seen = 0
def value; $seen += 1; 123; end
def take(*args, **kw); end
x = 1
r = []
r << defined?(take(
  value
))
r << defined?(take(
  k: value
))
r << defined?(take(
  x
))
r << defined?(take([
  value
]))
r << defined?(take(x,
  k: 1
))
r << defined?(value.then(
  value
))
r << defined?(take(*[
  value
]))
r << defined?([
  x
])
r << defined?(take(
  nope
))
r << defined?([1][
  value
])
p r, $seen
