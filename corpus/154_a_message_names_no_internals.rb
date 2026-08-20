# An error message is read by a person, so it must not name this interpreter's
# bookkeeping. The messages printed "AnonClass_0" and "(sng:111)" -- names that
# exist nowhere but in here -- while `Class.new.to_s` was already right.
#
# The message TEXT cannot be compared against the reference: the wording here
# follows ruby 3.4 ("undefined method 'x' for an instance of C") and the
# reference is 3.2.2 (`x' for x:C). So what is compared is the CLAIM: no
# bookkeeping name appears, and the shape ruby uses does.
c = Class.new
m = Module.new
o = Object.new
p [c.name, m.name]

def claim(e)
  msg = e.message
  [msg.include?("AnonClass"), msg.include?("AnonModule"), msg.include?("(sng:"),
   msg.include?("#<Class:0x") || msg.include?("#<Module:0x") || msg.include?("#<Class:#<")]
end

begin; c.new.foo; rescue NoMethodError => e; p claim(e); end
begin; c.foo;     rescue NoMethodError => e; p claim(e); end
begin; m.foo;     rescue NoMethodError => e; p claim(e); end
begin; o.singleton_class.foo;       rescue NoMethodError => e; p claim(e); end
begin; (class << o; self; end).foo; rescue NoMethodError => e; p claim(e); end

# a named class says its name; an anonymous one assigned to a constant takes it
class Named; end
Y = Class.new
p [Named.name, Y.name]
begin; Named.new.foo; rescue NoMethodError => e; p e.message.include?("Named"); end
begin; Y.new.foo; rescue NoMethodError => e; p [e.message.include?("Y"), e.message.include?("AnonClass")]; end

# the printed forms themselves, which ARE the same shape in both
p [c.to_s.start_with?("#<Class:0x"), m.to_s.start_with?("#<Module:0x")]
p [o.singleton_class.to_s.start_with?("#<Class:#<Object:0x"),
   o.singleton_class.inspect.start_with?("#<Class:#<Object:0x"),
   Named.singleton_class.to_s]
p [c.to_s.include?("AnonClass"), o.singleton_class.to_s.include?("(sng:")]
p Class.new.new.inspect.start_with?("#<#<Class:0x")
