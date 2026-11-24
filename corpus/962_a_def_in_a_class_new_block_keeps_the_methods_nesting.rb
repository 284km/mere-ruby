# A class opened as `class A::B::C` has one lexical scope, C: a constant in
# its methods is looked up in C and then at the top, not in A::B. A method's
# body already did that. A `def` inside a `Class.new { }` block that such a
# method runs captured an empty nesting instead, so its constants were looked
# up through every enclosing namespace of the name. activerecord's
# FixtureSet::RenderContext is that shape, and its `File.binread` found
# ActiveRecord::FixtureSet::File: "undefined method 'binread'".
module AR; class FS; class File; end; X = :fs; end; end
X = :top
class AR::FS::RC
  def self.mk = Class.new(Object) { def b = [File, X, Module.nesting] }
  def self.mk_two = Class.new(Object) { $n962 = Module.nesting; def b = [File, X, Module.nesting] }
  def self.mk_dm = Class.new(Object) { define_method(:b) { [File, X, Module.nesting] } }
  def self.mk_mod = Module.new { def b = [File, X]; def self.c = [File, X] }
  def self.blk = [1].map { [File, X, Module.nesting] }
  def self.mk_raise = (Class.new(Object) { raise "in the body" } rescue [File, X, Module.nesting])
  def inst = Class.new { def b = [File, X] }.new.b
  K = Class.new(Object) { def b = [File, X, Module.nesting] }
end
p AR::FS::RC.mk.new.b, AR::FS::RC.mk_two.new.b, $n962
p AR::FS::RC.mk_dm.new.b, AR::FS::RC.blk, AR::FS::RC::K.new.b
m = AR::FS::RC.mk_mod
p Object.new.extend(m).b, m.c, AR::FS::RC.new.inst
# the nesting is put back after the block, also when its body raises
p AR::FS::RC.mk_raise, Module.nesting
class AR::FS::RC
  def self.after = [File, X, Module.nesting]
end
p AR::FS::RC.after

# written nested, each enclosing scope is searched, as before
module AR
  class FS
    class RD
      def self.mk = Class.new(Object) { def b = [File, X, Module.nesting] }
    end
  end
end
p AR::FS::RD.mk.new.b
