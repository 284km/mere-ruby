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
fallback1009 = [BadJoinHash1009.new].join
p [:hash_bad_to_s, fallback1009.match?(/\A#<BadJoinHash1009:0x[0-9a-f]+>\z/), fallback1009.encoding.name]

saved_verbose1009 = $VERBOSE
$VERBOSE = nil
$join_identity_calls1009 = 0
class BadIdentityHash1009 < BadJoinHash1009
  def object_id
    $join_identity_calls1009 += 1
    raise "object_id must not be called"
  end
end
$VERBOSE = saved_verbose1009
fallback1009 = [BadIdentityHash1009.new].join
p [:native_hash_identity, fallback1009.match?(/\A#<BadIdentityHash1009:0x[0-9a-f]+>\z/),
   fallback1009.encoding.name, $join_identity_calls1009]

# Keep the Unicode class name while avoiding Ruby 4.0.10's disasm encoding
# error for this file's static class definition and constant reference.
unicode_hash1009 = Object.const_set("MauvaisÉHash1009", Class.new(BadJoinHash1009))
fallback1009 = [unicode_hash1009.new].join
p [:unicode_hash_fallback, fallback1009.match?(/\A#<MauvaisÉHash1009:0x[0-9a-f]+>\z/), fallback1009.encoding.name]

# The internal string conversion in join does not inherit the caller's
# refinements, while a direct to_s call in that lexical scope does.
module JoinHashRefinement1009
  refine Hash do
    def to_s = "refined"
  end
end
module JoinHashCaller1009
  using JoinHashRefinement1009
  def self.values = [{}.to_s, [{}].join]
end
p [:native_join_scope, JoinHashCaller1009.values]
