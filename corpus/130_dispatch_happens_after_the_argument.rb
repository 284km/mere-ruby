# Ruby evaluates a binary operator as receiver, then argument, then dispatch --
# and the argument can change what dispatch finds, because it can open the
# receiver's singleton class and define the operator there. This looked the
# receiver's singleton up FIRST and used the primitive, so a method defined
# while the argument ran was never reached.
def define_plus(str)
  class << str
    def +(_); "from singleton"; end
  end
  "argument"
end

s = +""
p(s + define_plus(s))

# the same shape without a singleton still works, and only evaluates each side
# once (a counter would show a double evaluation)
calls = 0
sideeffect = lambda { calls += 1; "b" }
p("a" + sideeffect.call)
p calls

# a String subclass whose #+ is defined while the argument runs is reached the
# same way (this is the shape the bootstraptest pair uses)
class Wrapper < String; end
def define_on(w)
  class << w
    def +(_); "sub singleton"; end
  end
  "arg"
end
w = Wrapper.new("")
p(w + define_on(w))
