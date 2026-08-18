# A class or module that was never assigned to a constant shows Ruby's
# `#<Class:0xADDR>`, not the internal bookkeeping name. This printed
# "AnonClass_0", which names an implementation detail and reads as if the class
# had that name -- while #name correctly answered nil, so the two disagreed.
def norm(s); s.sub(/0x[0-9a-f]+/, "0xX"); end

c = Class.new
p c.name
puts norm(c.inspect)
puts norm(c.to_s)

m = Module.new
p m.name
puts norm(m.inspect)

# ...and one that IS assigned to a constant takes that name, as before
K = Class.new
p K.name
p K.inspect
p K.new.class.name

# an anonymous exception class, the shape gems declare theirs in
E = Class.new(StandardError)
p E.name
d = Class.new(StandardError)
puts norm(d.inspect)
begin
  raise d, "boom"
rescue => e
  puts norm(e.class.inspect)
  p e.message
end
