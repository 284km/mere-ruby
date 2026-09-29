# `c.class_eval(&blk)` spends the block it was handed: a later method taking
# a literal block gets THAT block, not the one passed before.
class Maker
  def self.make(&b)
    c = Class.new
    c.class_eval(&b)
    c
  end
end
a = Maker.make { def hi = :a }
b = Maker.make { def hi = :b }
p [a.new.hi, b.new.hi]

# Data.new turns positional arguments into keywords, so an #initialize
# override always sees keywords; [] passes keywords as keywords
Measure = Data.define(:amount, :unit) do
  def initialize(*rest, **kw)
    $seen = [rest, kw]
    super
  end
end
Measure.new(42, "m")
p $seen
Measure[amount: 1, unit: "km"]
p $seen
Area = Data.define(:width, :height, :area) do
  def initialize(width:, height:) = super(width: width, height: height, area: width * height)
end
p Area.new(width: 2, height: 3)

# keys: a String works, #to_str converts, anything else is refused
Pt = Data.define(:x, :y)
p Pt.new("x" => 1, y: 2)
begin; Pt.new(1 => 2); rescue TypeError => e; p e.message; end
k = Object.new
def k.to_str = "z"
begin; Pt.new(x: 1, y: 2, k => 3); rescue ArgumentError => e; p e.message; end

# inspect names the class's real name and survives a data holding itself
Named = Data.define(:v) { def self.name = "Other" }
p Named.new(1)
r = Pt.allocate
r.send(:initialize, x: 1, y: r)
p r
