# After `Object.send(:remove_const, :Name)`, `class Name` makes a NEW class.
# The old one is still there for whoever holds it -- its instances, a
# variable -- and the new one has none of its methods, constants, mixins or
# superclass.
#
# Rails' migrator loads a migration with
#
#   Object.send(:remove_const, name) rescue nil
#   load(File.expand_path(filename))
#   name.constantize.new(name, version)
#
# and activerecord's migration_test defines, in the test file itself,
#
#   class ValidPeopleHaveLastNames < ActiveRecord::Migration::Current
#     def change; drop_table :people; end
#   end
#
# to see that the name collision is harmless. Here the class the file defined
# was the old class reopened, #change was still its method, and `migrator.up`
# dropped the table: 37 tests of that file failed after it.
module Helper; def helped = :helped; end
class A
  include Helper
  X = 1
  @civ = :old
  def self.civ = @civ
  def self.cm = :old_cm
  def change = :old_change
end
old = A
o = old.new
Object.send(:remove_const, :A)
p old.name, old, o.class, o.change, old.cm, old.civ, defined?(A)

class A
  def self.up = :new_up
end
p A.equal?(old), A == old, A.name, old.name
p A.new.respond_to?(:change), A.respond_to?(:cm), A.respond_to?(:up), old.respond_to?(:up)
p A.instance_methods(false), old.instance_methods(false)
p A.const_defined?(:X), old.const_defined?(:X), A.include?(Helper), old.include?(Helper), A.respond_to?(:civ)
# the old class and its instance are what they were
p o.is_a?(A), o.is_a?(old), o.change, o.helped, old::X, A.new.class == o.class
# the new class is reopened by its name from here on
class A; def more = :more; Y = 2; end
p A.new.more, A::Y, A.instance_methods(false).sort, old.method_defined?(:more)
p A.new.class, A.new.class.name, A.to_s, A.inspect, Marshal.load(Marshal.dump(A.new)).class == A

# another superclass is no mismatch: it is another class
class S1; end
class S2; end
class B < S1; def b1 = 1; end
ob = B
Object.send(:remove_const, :B)
class B < S2; def b2 = 2; end
p B.superclass, ob.superclass, B.new.respond_to?(:b1), B.new.b2
# ...and a superclass given by an expression
Object.send(:remove_const, :B)
class B < Struct.new(:a); def b3 = 3; end
p B.superclass.superclass, B.new(1).a, B.new.respond_to?(:b2), B.instance_methods(false)

# a module
module M; def self.f = 1; Z = 1; end
om = M
Object.send(:remove_const, :M)
module M; def self.g = 2; end
p M.respond_to?(:f), M.g, om.f, om.equal?(M), M.const_defined?(:Z), M.name, om.name
# a class where a module was, and the other way round
Object.send(:remove_const, :M)
class M; end
p M.class, om.class

# nested
class Outer
  class Inner; def i1 = 1; end
end
oi = Outer::Inner
Outer.send(:remove_const, :Inner)
class Outer
  class Inner; def i2 = 2; end
end
p Outer::Inner.equal?(oi), Outer::Inner.name, Outer::Inner.new.respond_to?(:i1), Outer::Inner.new.i2, oi.new.i1
Outer.send(:remove_const, :Inner)
class Outer::Inner; def i3 = 3; end
p Outer::Inner.instance_methods(false), Outer::Inner.name, Outer.constants

# #inherited hears of the new class
class Base
  def self.inherited(k) = (@subs ||= []) << k.name
  def self.subs = @subs
end
class Kid < Base; end
Object.send(:remove_const, :Kid)
class Kid < Base; end
p Base.subs

# the constant given back is the old class again, and `class` reopens it
class R; def r1 = 1; end
keep = R
Object.send(:remove_const, :R)
R = keep
class R; def r2 = 2; end
p R.equal?(keep), R.new.r1, R.new.r2

# what the migrator does: remove, load the file, build by name
require "tmpdir"
dir = Dir.mktmpdir("mrb_removed")
file = File.join(dir, "1_people.rb")
File.write(file, "class PeopleMigration\n  def self.up = :file_up\nend\n")
class PeopleMigration
  def change = :dropped_the_table
end
begin
  3.times do
    Object.send(:remove_const, :PeopleMigration) rescue nil
    load(file)
    k = Object.const_get("PeopleMigration")
    p [k.new.respond_to?(:change), k.up, k.name]
  end
ensure
  File.delete(file)
  Dir.rmdir(dir)
end
