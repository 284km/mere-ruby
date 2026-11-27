def location_for1009
  caller_locations(0, 1).first
end
loc = location_for1009
p [loc].join == loc.to_s
p [loc, [loc]].join("\n") == [loc.to_s, loc.to_s].join("\n")
class CustomString1009
  def to_s = 'custom'
end
p [loc, CustomString1009.new].join('|') == "#{loc}|custom"
obj = Object.new
p [obj].join == obj.to_s
p [Object.new].join.match?(/\A#<Object:/)

class JoinPerson1009
  def initialize = @name = "example"
end
person1009 = JoinPerson1009.new
hash1009 = { person: person1009 }
p [:hash_join, [hash1009].join == hash1009.to_s,
   [[hash1009]].join == hash1009.to_s,
   [{ person: [person1009] }].join.include?("#<JoinPerson1009:")]

class JoinHash1009 < Hash
  attr_reader :calls
  def to_s
    @calls = (@calls || 0) + 1
    "custom".encode("ISO-8859-1")
  end
end
custom1009 = JoinHash1009.new
joined1009 = [custom1009].join
p [:hash_override, joined1009, joined1009.encoding.name, custom1009.calls]

class BadJoinHash1009 < Hash
  def to_s = 123
end
p [:hash_bad_to_s, [BadJoinHash1009.new].join.match?(/\A#<BadJoinHash1009:0x[0-9a-f]+>\z/)]
