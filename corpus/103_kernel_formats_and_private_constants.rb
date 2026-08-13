# The Kernel module functions are reachable by name, so they are reachable
# through the module too -- which is what code that inherits from BasicObject
# has to do.
Kernel.puts "kernel puts"
Kernel.print "kernel print\n"
Kernel.p :kernel_p
p Kernel.format("%05.1f", 3.14159)
p Kernel.sprintf("%s-%s", 1, 2)
p [Kernel.Integer("42"), Kernel.String(7), Kernel.Array(nil)]

class ViaBasic < BasicObject
  def shout
    ::Kernel.format("%s!", "x")
  end
end
p ViaBasic.new.shout

# Ruby rounds a tie to the even digit, and it rounds the shortest decimal
# representation rather than the scaled binary value.
p [format("%.2f", 0.125), format("%.2f", 2.675), format("%.2f", 12.345)]
p [format("%.0f", 0.5), format("%.0f", 1.5), format("%.0f", 2.5)]
p [format("%.3e", 1234.5), format("%.3e", 12.345), format("%.3e", 0.12345)]

# A float too large for the scaled arithmetic is still printed exactly.
p format("%.2f", 6.02e23)
p format("%.6f", 1e15)
p format("%.3f", 1e16)

# %g picks its style from the exponent of the value rounded to p significant
# digits, and `#` keeps the zeros %g would strip.
p [format("%g", 98765.4321), format("%g", 987654.321), format("%g", 999999.5)]
p [format("%.3g", 98765.4321), format("%.10g", 98765.4321), format("%.1g", 100.0)]
p [format("%#g", 1.0), format("%#g", 100.0), format("%#g", 987654.321)]

# A String may hold a zero byte, and print has to write all of it.
s = "a\0b\0c"
print s
print "\n"
$stdout.write(s)
print "\n"
p s.bytesize

# private_constant closes off the scope operator, not the lexical name.
module Hidden
  SECRET = 42
  OPEN = 1
  private_constant :SECRET

  def self.peek
    SECRET
  end
end
p Hidden.peek
p Hidden.constants
p Hidden::OPEN
begin
  Hidden::SECRET
rescue NameError => e
  puts e.message
end
p Hidden.const_get(:SECRET)

class TwoPrivate
  A = 1
  B = 2
  private_constant :A, :B

  def get
    [A, B]
  end
end
p TwoPrivate.new.get
p TwoPrivate.constants
