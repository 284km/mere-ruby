# Marshal, string interpolation and an IO's write path keep their builtin
# behavior when the program redefines core methods, as test_optimization's
# assert_redefine_method children need (marshal.c and the interpolation are C)

DATA0 = [1, "ab", {k: 2.5}, :sym, nil, 300, -70000, 2**70, 1..3, [[]]]
def round_trip(tag)
  s = [Marshal.dump(DATA0)].pack("m")
  back = Marshal.load(s.unpack1("m"))
  tok = "T"
  io = IO.new(1, "w")
  io.puts "#{tok}<#{tag}>", s.unpack1("m").bytesize
  io.flush
  p back.size, back[2], back[7]
end

round_trip("plain")

class Integer
  undef &
  def &(*args) = args[0]
end
round_trip("int-and")

class Array
  undef empty?
  def empty?(*args) = args[0]
end
round_trip("ary-empty")

class String
  undef <<
  def <<(*args) = args[0]
end
round_trip("str-ltlt")
p "a" << "b"

class String
  undef +
  def +(*args) = args[0]
end
round_trip("str-plus")
x = 7
p "a#{x}b", "a" + "b"
