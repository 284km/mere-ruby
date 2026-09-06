# Before refusing, ruby asks. These are the questions it asks, and the answers
# it gives when nothing answers.

def result
  yield
rescue StandardError => e
  [e.class, e.message]
end

# an object that converts is converted -- to_int, to_str, to_f, divmod, coerce
to_three = Object.new
def to_three.to_int = 3
p 7.allbits?(to_three)
p [7, 8, 9, 10].fetch_values(to_three)

sourcey = Object.new
def sourcey.to_str = "1 + 1"
p eval(sourcey)

floaty = Object.new
def floaty.to_f = 2.0
p 1.coerce(floaty)
p 1.0.coerce(floaty)

sleepy = Object.new
def sleepy.divmod(x) = [0, 0]
p sleep(sleepy)

# ...including a PRIVATE #coerce, which respond_to? does not see
class Coercer
  private def coerce(other) = [other, 2]
end
p((10**20) + Coercer.new)
p((1..5).step(Coercer.new).to_a)

# a Complex divides a real
p 1.0.fdiv(Complex(1, 2))

# a non-numeric init is the accumulator, and its own + runs first
class Plus
  def +(other) = 42
end
p [1, 2].sum(Plus.new)

# ...and what nothing can convert is refused, by name
p result { 7.allbits?(Object.new) }
p result { 1.coerce(Object.new) }
p result { sleep(Object.new) }
p result { eval(Object.new) }

# an exception carries its parts
p SystemExit.new(true, "ok").status
p SystemExit.new(false).status
p SystemExit.new(2, "bye").success?
p SignalException.new("INT").signm
p SignalException.new(2).signo
p SignalException.new("INT").signo
p result { SystemCallError.new }
p Errno::ENOENT.new.message
p Class.new(Errno::ENOENT).new.message
begin
  NameError.new("m", :foo).receiver
rescue ArgumentError => e
  p e.message
end
begin
  nil.no_such
rescue NoMethodError => e
  p [e.name, e.receiver]
end

# a break out of a proc is not a value
p result { Proc.new { break 1 }.call }
p lambda { break 2 }.call

# a symbol is a string where a string method is asked for
p [:abc.casecmp(:ABC), :abc.casecmp?(:ABC), :abc.casecmp("ABC")]
p [:"$ruby!".inspect, :$ruby.inspect, :ruby!.inspect, :@ivar.inspect]

# a singleton method binds to a subclass
class Parent
  def self.who = :parent
end
class Child < Parent; end
p Parent.singleton_class.instance_method(:who).bind(Child).call
