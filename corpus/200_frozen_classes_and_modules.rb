# `K.freeze` was a no-op: it did not even make `K.frozen?` true, and the class
# went on accepting defs, includes, constants, attrs and visibility changes.
#
# One fact -- "this class is frozen" -- with a door for every writer. The list
# below is ruby's own answer, not a guess: each name was called on a frozen
# class and the ones that raise FrozenError are the ones checked here. Three
# do NOT raise, and they are checked too: a bare `private` changes nothing yet,
# and a frozen class is still a perfectly good class to instantiate, subclass
# and copy.

def t(label)
  yield
  puts "#{label}: ok"
rescue Exception => e
  puts "#{label}: #{e.class}"
end

def frozen_class
  k = Class.new
  k.const_set(:C1, 1)
  k.instance_variable_set(:@x, 1)
  k.freeze
  k
end

p frozen_class.frozen?

t(:define_method)  { frozen_class.send(:define_method, :q) {} }
t(:alias_method)   { frozen_class.send(:alias_method, :aa, :class) }
t(:remove_method)  { frozen_class.send(:remove_method, :zz) }
t(:undef_method)   { frozen_class.send(:undef_method, :zz) }
t(:attr_accessor)  { frozen_class.send(:attr_accessor, :w) }
t(:attr_reader)    { frozen_class.send(:attr_reader, :w) }
t(:attr_writer)    { frozen_class.send(:attr_writer, :w) }
t(:attr)           { frozen_class.send(:attr, :w) }
t(:const_set)      { frozen_class.const_set(:C2, 1) }
t(:remove_const)   { frozen_class.send(:remove_const, :C1) }
t(:include)        { frozen_class.include(Comparable) }
t(:prepend)        { frozen_class.prepend(Comparable) }
t(:extend)         { frozen_class.extend(Comparable) }
t(:ivar_set)       { frozen_class.instance_variable_set(:@y, 1) }
t(:ivar_remove)    { frozen_class.send(:remove_instance_variable, :@x) }
t(:private_named)  { frozen_class.send(:private, :class) }
t(:public_named)   { frozen_class.send(:public, :class) }
t(:protected_named){ frozen_class.send(:protected, :class) }
t(:private_class_method) { frozen_class.send(:private_class_method, :name) }
t(:public_class_method)  { frozen_class.send(:public_class_method, :name) }
t(:private_constant)     { frozen_class.send(:private_constant, :C1) }
t(:ruby2_keywords)       { frozen_class.send(:ruby2_keywords, :zz) }
t(:define_singleton)     { frozen_class.define_singleton_method(:sq) {} }
t(:singleton_def)        { k = frozen_class; def k.sm; end }
t(:class_eval_def)       { frozen_class.class_eval { def z; end } }
t(:module_eval_def)      { frozen_class.module_eval { def z2; end } }
t(:instance_eval_def)    { frozen_class.instance_eval { def z3; end } }

# ...and the three that are allowed
t(:private_bare)   { frozen_class.send(:private) }
t(:new)            { frozen_class.new }
t(:subclass)       { Class.new(frozen_class) }
t(:dup)            { frozen_class.dup }
t(:clone)          { frozen_class.clone }

# a frozen class refuses each WRITE in a reopened body, not the body itself
K = Class.new
K.freeze
t(:empty_reopen)   { eval("class K; end") }
t(:body_const)     { eval("class K; ZZ = 1; end") }
t(:body_def)       { eval("class K; def z; end; end") }

# the refusal names what it refused: a Class, a Module, or the object
M = Module.new
M.freeze
begin
  M.module_eval { def q; end }
rescue FrozenError => e
  puts "module: #{e.message.sub(/0x\h+/, '0xXX')}"
end
class Named; end
Named.freeze
begin
  Named.class_eval { def q; end }
rescue FrozenError => e
  puts "named: #{e.message}"
end
o = Object.new
o.freeze
begin
  o.instance_eval { def q; end }
rescue FrozenError => e
  puts "object: #{e.message.sub(/0x\h+/, '0xXX')}"
end
begin
  o.extend(Comparable)
rescue FrozenError => e
  puts "extend: #{e.message.sub(/0x\h+/, '0xXX')}"
end

# freezing from INSIDE the body: `Module.new { self.freeze; def foo; end }` runs
# its body as a block with self rebound, not through the class-body walker, so
# it needs its own check.
t(:mod_new_freeze) { Module.new { self.freeze; def foo; end } }
t(:cls_new_freeze) { Class.new { self.freeze; def foo; end } }
t(:body_freeze)    { eval("class FZ; freeze; def foo; end; end") }
