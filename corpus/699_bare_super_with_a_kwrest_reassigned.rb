# A bare super from a method with `**h` hands h on as its keywords; when the
# method has reassigned h to something that is not a Hash, ruby refuses it as
# the Hash being built (Check_Type), not as a `**` splat's conversion. On the
# VM that is core#hash_merge_ptr's first value.

class Parent
  def initialize(d:, **rest) = (@d = d; @rest = rest)
  def got = [@d, @rest]
end
class Child < Parent
  def initialize(d:, **h)
    h = $replace if $replace != :keep
    super
  end
end

class WithToHash
  def to_hash = {z: 1}
end

[:keep, [2, 3], nil, 7, WithToHash.new, {e: 5}].each do |r|
  $replace = r
  begin
    p Child.new(d: 4, x: 1).got
  rescue TypeError => e
    p [e.class, e.message]
  end
end

# a `**` in a literal still converts, and says so
begin
  {**[2, 3]}
rescue TypeError => e
  p e.message
end
p({a: 1, **WithToHash.new})
