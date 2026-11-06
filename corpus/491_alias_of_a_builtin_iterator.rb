# An alias of a builtin ITERATOR, called without a block, is its Enumerator:
# `alias old_times times; 3.old_times` was "undefined method 'times'" (the
# primitive layer the alias went to has no blockless times), and so was a
# Method of it. Once the class redefines the name, the alias still reaches the
# builtin with a block, and without one it is an Enumerator over the name,
# whose #each reaches the new method, as ruby's is.
class Integer
  alias old_times times
  alias_method :o_upto, :upto
  alias o_downto downto
  alias o_step step
  alias o_succ succ
end
p 3.old_times.to_a, 3.old_times.map { |i| i * 2 }, 3.respond_to?(:old_times), Integer.instance_method(:old_times).name
3.old_times { |i| print i }
puts
p 1.o_upto(3).to_a, 3.o_downto(1).map { |x| x * 2 }, 1.o_step(7, 3).to_a, 1.o_succ
class Array
  alias o_each_slice each_slice
  alias o_map map
  alias o_each_with_index each_with_index
  alias o_select select
end
p [1, 2, 3].o_each_slice(2).to_a, [1, 2].o_map.with_index.to_a, [5, 6].o_each_with_index.to_a, [1, 2].o_select(&:odd?)
p [1, 2].o_map { |x| x + 1 }
class Hash
  alias o_each_pair each_pair
end
class String
  alias o_each_line each_line
end
class Range
  alias o_each each
end
p({a: 1}.o_each_pair.to_a, "a\nb".o_each_line.to_a, (1..3).o_each.to_a)
m = 3.method(:times)
um = Integer.instance_method(:times)
class Integer
  def times
    yield 42
    self
  end
end
3.old_times { |i| print i }
puts
3.times { |i| p i }
p 2.old_times.to_a, m.call.to_a, um.bind(2).call.to_a
um.bind_call(2) { |i| print i }
puts
class Array
  def map = :mine
end
p [1, 2].o_map { |x| x * 3 }, [1, 2].map { }, [1, 2].o_map.to_a
class Integer
  def upto(*) = :mine
end
p 1.o_upto(2).to_a, 1.o_upto(2) { }, 1.upto(2), 1.method(:o_upto).call(2).to_a
