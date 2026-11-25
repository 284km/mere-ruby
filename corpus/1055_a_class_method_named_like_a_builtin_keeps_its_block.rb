# `C.count(:col) { ... }` calls C's own class method with the block. Whether
# a builtin answers a name is asked of the receiver's class -- and for a
# class as the receiver that is its singleton class. It was asked of the
# class's instance side, where nothing defines `count`, so the call was
# taken for the builtin Enumerable#count: "given block not used", and the
# block was dropped.
#
# ActiveRecord defines `Account.count` by `delegate ... to: :all`, and
# Relation#count raises ArgumentError for a column name with a block. The
# test expecting that error saw none.
class Rel
  def count(col = nil) = block_given? ? [:blk, col, yield] : [:noblk, col]
  def find_index(v = nil) = block_given? ? [:blk, v] : [:noblk, v]
  def sum(init = 0) = block_given? ? [:blk, init] : [:noblk, init]
end
class Mdl
  def self.all = Rel.new
  class << self
    def count(...) = all.count(...)
    def find_index(...) = all.find_index(...)
  end
  def self.sum(...) = all.sum(...)
end
p Mdl.count(:x) { true }
p Mdl.count { 1 }, Mdl.count(:y), Mdl.count
p Mdl.find_index(3) { true }, Mdl.sum(10) { |x| x }
# through a subclass, and a module the class extends
class Sub < Mdl; end
p Sub.count(:x) { :sub }
module Q; def count(c = nil) = block_given? ? [:q_blk, c] : [:q_noblk, c]; end
class Ext; extend Q; end
p Ext.count(:x) { 1 }
# a module function
module MF; def self.count(c = nil) = block_given? ? [:mf_blk, c] : [:mf_noblk, c]; end
p MF.count(1) { 2 }
# the builtin rule itself is unchanged: an argument beats the block
p [1, 2, 2].count(2) { |x| x > 100 }
