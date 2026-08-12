# const_missing is the documented hook, and const_get has to honour it too --
# regexp_parser resolves its per-ruby-version syntax classes entirely through
# const_get. A hook that handles some names and calls `super` for the rest
# needs Module#const_missing to actually exist as the landing place.
module Lookup
  def const_missing(n)
    return "made:#{n}" if n.to_s.start_with?("V")
    super
  end
end

module Reg
  extend Lookup
  KNOWN = 1
end

p Reg::KNOWN
p Reg.const_get(:KNOWN)
p Reg::V1_2
p Reg.const_get(:V9)
begin
  Reg::Other
rescue NameError => e
  puts "#{e.class}: #{e.message}"
end
begin
  Reg.const_get(:AlsoMissing)
rescue NameError => e
  puts "#{e.class}: #{e.message}"
end
begin
  Object.const_get(:NoSuchThingAnywhere)
rescue NameError => e
  puts "#{e.class}: #{e.message}"
end

# nil.to_h is {} -- how a library writes `maybe_nil.to_h.map { }` with no guard
p nil.to_h
p nil.to_a
p({ a: 1 }.to_h)
p [[1, 2], [3, 4]].to_h
p [].to_h

# to_h with a block maps each element to a pair
p({ a: 1, b: 2 }.to_h { |k, v| [k, v * 10] })
p [[1, 2], [3, 4]].to_h { |k, v| [k + 100, v] }
p [1, 2].to_h { |x| [x, x * x] }
