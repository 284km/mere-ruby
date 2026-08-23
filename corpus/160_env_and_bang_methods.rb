# ENV answers as the hash it is, and a bang method answers nil when it changed
# nothing.
#
# ENV's dispatch used to match on the RECEIVER and then handle a fixed list of
# names, ending in "undefined method for ENV" -- so equal?, frozen?, hash,
# itself and dup raised on the one object where they work everywhere else, and
# every Hash method it had not thought of was simply absent.
#
# The bang rule was implemented for Array#compact! and String#upcase! and
# missing from reject! / select! / uniq! / flatten! on both Array and Hash.

# --- the universal protocol is not ENV's to shadow ----------------------
puts ENV.equal?(ENV)
puts ENV.frozen?
puts ENV.hash.is_a?(Integer)
puts ENV.object_id.is_a?(Integer)
puts ENV.is_a?(Object)

# --- ENV names itself, and says the same thing however it is asked ------
ENV.clear
ENV["MRB_A"] = "1"
ENV["MRB_B"] = "2"
puts ENV.to_s
puts "#{ENV}"
p ENV
p ENV.inspect == ENV.to_hash.inspect

# --- what ENV answers, it answers as a hash -----------------------------
p ENV.invert
p ENV.values_at("MRB_A", "MRB_B")
p ENV.has_value?("1")
p ENV.rassoc("1")
p ENV.slice("MRB_A")
p ENV.except("MRB_A")
p ENV.select { |k, v| k == "MRB_A" }
p ENV.reject { |k, v| k == "MRB_A" }
p ENV.map { |k, v| k }.sort
p ENV.each { |k, v| }.equal?(ENV)
p ENV.each_key { |k| }.equal?(ENV)
p ENV.count

# mutating through a block writes back to the environment
ENV.delete_if { |k, v| k == "MRB_A" }
p ENV.to_hash
ENV["MRB_A"] = "1"
ENV.keep_if { |k, v| k == "MRB_A" }
p ENV.to_hash
p ENV.reject! { |k, v| false }
ENV.clear

# --- Hash#slice keeps the keys; it is not Hash#[] -----------------------
p({ "a" => 1, "b" => 2 }.slice("a"))
p({ "a" => nil }.slice("a"))
p({ "a" => 1 }.slice("zz"))
# and slice IS [] for the sequence types
p "abcdef".slice(1, 3)
p [1, 2, 3].slice(0, 2)

# --- a bang method answers nil when nothing changed ---------------------
p [1, 2].reject! { |x| false }
p [1, 2].select! { |x| true }
p [1, 2].uniq!
p [1, 2].flatten!
p({ "a" => 1 }.reject! { |k, v| false })
p({ "a" => 1 }.select! { |k, v| true })

# ... and self when something did
p [1, 2].reject! { |x| x == 1 }
p [1, 1].uniq!
p [[1], [2]].flatten!       # same LENGTH, different value
p [[[1]]].flatten!(1)
p [[1]].flatten!(0)         # depth 0 changes nothing
p({ "a" => 1 }.reject! { |k, v| true })

# delete_if and keep_if answer self either way
p [1, 2].delete_if { |x| false }
p({ "a" => 1 }.keep_if { |k, v| true })
ENV.clear
ENV["MRB_S"]="1"
p ENV.shift
p ENV.shift
p ENV.rehash
