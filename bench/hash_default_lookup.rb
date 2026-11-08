# Missing lookups must use the same key index as ordinary reads.
count = (ARGV[0] || "20000").to_i
h = Hash.new { |_hash, key| key }
2000.times { |i| h["key#{i}"] = i }
missing = "missing"
i = 0
while i < count
  raise "default" unless h[missing].equal?(missing)
  raise "present" unless h["key1999"] == 1999
  i += 1
end
puts "hash default: hits and misses preserved"
