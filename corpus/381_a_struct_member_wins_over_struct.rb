# A struct's member accessors are its generated class's own methods, and
# #each / #size / #to_a / #hash / #== are Struct's, one class up -- so a member
# may take any of those names, and a module the class includes sits between.
%i[each size to_a members hash each_pair].each do |m|
  p [m, Struct.new(m).new(42).send(m)]
end

mod = Module.new { def hash = "different" }
p Struct.new(:arg) { include mod }.new.hash

# == and eql? are false across struct classes, and survive a struct that
# holds itself; so does #hash, and eql? structs hash alike
Car = Struct.new(:make, :model)
p Car.new(1, 2) == Struct.new(:make, :model).new(1, 2)
x = Car.new("Honda", "Accord")
x.make = x
stepping = Car.new("Honda", "Accord")
stone = Car.new(stepping, "Accord")
stepping.make = stone
p [x == stepping, x.eql?(stepping)]
stone.model = "Civic"
p x == stepping
a = Car.new("Honda", "Accord"); a.make = a
b = Car.new(a, "Accord")
p a.hash == b.hash
p Struct.new(:x).new(1).hash == Struct.new(:y).new(1).hash

# initialize speaks in ruby's own words
T = Struct.new(:a, :b)
begin; T.new(1, 2, 3); rescue ArgumentError => e; p e.message; end
begin; T.new(1, 2, c: 3); rescue ArgumentError => e; p e.message; end
K = Struct.new(:name, :legs, keyword_init: true)
p K.new({name: "elefant", legs: 4})
begin; K.new(name: "x", foo: 1, bar: 2); rescue ArgumentError => e; p e.message; end
begin; K.new("x"); rescue ArgumentError => e; p e.message; end

# the block is handed the new class
given = nil
k = Struct.new(:attr) { |c| given = c }
p k.equal?(given)
