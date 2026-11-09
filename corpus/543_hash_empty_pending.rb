calls = 0
h = Hash.new { calls += 1 }
raise "new hash" unless h.empty?
1000.times do |i|
  h[i] = [i]
  raise "pending pair missing" if h.empty?
end
h[0] = :replacement
raise "overwritten hash" if h.empty?
raise "default called" unless calls == 0
raise "overwrite lost" unless h[0] == :replacement
h.delete(0)
raise "remaining pairs lost" if h.empty?
h.clear
raise "clear" unless h.empty?
h[:last] = :value
raise "new queue" if h.empty?
h.delete(:last)
raise "last deletion" unless h.empty?
key = [1]
h[key] = true
key << 2
raise "mutable key" if h.empty?
h.rehash
raise "rehash" if h.empty?
h.delete(key)
raise "rehash deletion" unless h.empty?
identity = {}.compare_by_identity
identity[key] = false
raise "false identity value" if identity.empty?
identity.delete(key)
raise "identity deletion" unless identity.empty?
puts :ok
