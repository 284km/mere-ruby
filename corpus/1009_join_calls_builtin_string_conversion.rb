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
