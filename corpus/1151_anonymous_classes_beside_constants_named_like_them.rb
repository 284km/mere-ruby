# An anonymous class or module is kept under a name of its own making
# ("AnonClass_7"). A program may name constants that way too, and a class made
# after that must not take one of them -- and nothing else changes.
def anon?(k) = k.name.nil? && k.to_s.start_with?(k.is_a?(Class) ? "#<Class:0x" : "#<Module:0x")

# made before any such constant
early = Class.new { def hi = :early }
p [anon?(early), early.new.hi]

# 1. constants named like them, written out
AnonClass_0 = :taken
AnonModule_0 = :taken_too
Struct_0 = :also_taken
# 2. ...and by Object.const_set, over the range the next ones would use
(1..3000).each do |i|
  Object.const_set("AnonClass_#{i}", i)
  Object.const_set("AnonModule_#{i}", -i)
  Object.const_set("Struct_#{i}", i * 2)
end

made = (1..20).map { Class.new { def hi = :class } }
mods = (1..20).map { Module.new { def self.hi = :module } }
structs = (1..5).map { Struct.new(:a) }
p made.all? { |k| anon?(k) && k.new.hi == :class }
p mods.all? { |m| anon?(m) && m.hi == :module }
p structs.map { |s| [s.name, s.new(1).a] }
p [AnonClass_0, AnonModule_0, Struct_0]
p [AnonClass_1, AnonClass_1500, AnonClass_3000, AnonModule_2999, Struct_17]
p (1..3000).all? { |i| Object.const_get("AnonClass_#{i}") == i && Object.const_get("AnonModule_#{i}") == -i }
p (made + mods).uniq.size, [early.new.hi, anon?(early)]

# 3. after that, an anonymous class given a name
k = Class.new { def hi = :named }
Named = k
p [k.name, Named.new.hi, k.to_s]
inc = Module.new
Inside = Module.new
Inside.const_set(:Deep, Class.new { include inc })
p [Inside::Deep.name, Inside::Deep.include?(inc), anon?(inc)]
later = Class.new(Named)
p [anon?(later), later.superclass, later.new.hi]
GC.start
p [made.first.new.hi, Named.new.hi, AnonClass_0, AnonClass_42]
