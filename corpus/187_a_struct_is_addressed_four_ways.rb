# A Struct's members are reachable by name, by string, by index and by index
# from the end -- and every one of those four has its own refusal.

Point = Struct.new(:x, :y)
KwPoint = Struct.new(:x, :y, keyword_init: true)
p3 = Point.new(1, 2)

p Point[3, 4].to_a, Point.new(5).to_a, Point.members, Point.new(1, 2).size
p p3[0], p3[:x], p3["x"], p3[-1], p3[1]
q = Point.new(1, 2)
p q[:x] = 9, q[0], (q["y"] = 8), q[-1], (q[-2] = 7), q.x
p p3.to_a, p3.values, p3.deconstruct, p3.to_h, p3.values_at(0, 1), p3.values_at(-1)
p p3.dig(:x), p3.dig("x"), p3.dig(0), p3.dig(:nope), p3.dig(9)
p Point.new({ a: 1 }, 2).dig(:x, :a), Point.new(nil, 2).dig(:x, :a)
p p3.to_h { |k, v| [k.to_s, v * 10] }
p p3.each_pair.to_a, p3.each_pair { |k, v| }.equal?(p3), p3.each { |v| }.equal?(p3)
p p3.deconstruct_keys(nil), p3.deconstruct_keys([:x]), p3.deconstruct_keys(["x"])
p p3.deconstruct_keys([0, 1]), p3.deconstruct_keys([:x, :y, :z]), p3.deconstruct_keys([:x, :nope, :y])

# every wrong key has its own refusal
[-> { p3[9] }, -> { p3[-9] }, -> { p3[:nope] }, -> { p3["nope"] },
 -> { p3[Object.new] }, -> { p3.values_at(9) }, -> { p3.values_at(-9) },
 -> { q[9] = 1 }, -> { q[:nope] = 1 }, -> { p3.dig(Object.new) }].each do |f|
  begin
    f.call
  rescue IndexError, NameError, TypeError => e
    puts e.class.to_s + ": " + e.message
  end
end

# two structs of the same class and content are the same value
p Point.new(1, 2) == Point.new(1, 2), Point.new(1, 2).eql?(Point.new(1, 2))
p Point.new(1, 2).hash == Point.new(1, 2).hash
p Point.new(1, 2).eql?([1, 2]), Point.new(1, 2) == Point.new(1, 3)

# keyword_init? answers what the class was built with -- and nil is not false
p Point.keyword_init?, KwPoint.keyword_init?
p Struct.new(:z, keyword_init: false).keyword_init?
p Struct.new(:z, keyword_init: nil).keyword_init?
p KwPoint.new(x: 1, y: 2).to_a

# the pairs that are one method under two names
p Point.instance_method(:deconstruct) == Point.instance_method(:to_a)
p Point.instance_method(:values) == Point.instance_method(:to_a)
p Point.instance_method(:length) == Point.instance_method(:size)
p Point.new(1, 2).method(:values) == Point.new(1, 2).method(:to_a)

# ...and a struct still prints as a struct
p p3.inspect, p3.to_s, "#{p3}"
p Point.new(1, 2).frozen?, p3.respond_to?(:x), p3.respond_to?(:nope)
