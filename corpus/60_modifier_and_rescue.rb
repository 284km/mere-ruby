# A `rescue` modifier can be followed by another modifier:
# `a rescue nil if c` is `(a rescue nil) if c`.
x = nil
x.foo rescue nil if x
p :a
y = 1
y.to_s rescue nil if y
p :b
w = 1 rescue nil
p w
z = (2 rescue 3)
p z
p((1 if true))
p((1 if false).inspect)

# a `rescue` clause can name a class from the top level
module Outer
  class Err < StandardError; end
end
begin
  raise Outer::Err, "x"
rescue ::Outer::Err => e
  p [e.class.to_s, e.message]
end
begin
  raise ArgumentError, "y"
rescue ::ArgumentError => e
  p e.message
end
begin
  raise TypeError, "t"
rescue ::ArgumentError, ::TypeError => e
  p [e.class.to_s, e.message]
end
begin
  ::Kernel::raise ::ArgumentError, "z"
rescue => e
  p e.message
end

# an `if` used as an expression, spanning lines
v = if true
      1
    else
      2
    end
p v
