# A constant knows where it was defined: Module#const_source_location answers
# [file, line] for an assignment, a `class`/`module` keyword, const_set and an
# eval with a given file and line; [] for one the interpreter defined itself;
# nil for none. The name follows const_get's rules (a Symbol is one constant,
# a String may be a path, `inherit` governs the first segment only), and the
# last segment is only looked at -- an autoload not yet loaded answers where
# `autoload` was called.

module Shop
  RATE = 1
  class Item
    SKU = 2
  end
  module Taxed
    VAT = 3
  end
end

class Gadget < Shop::Item
  include Shop::Taxed
end

TOP_LEVEL = 4

p Shop.const_source_location(:RATE)
p Shop.const_source_location(:Item)
p Shop.const_source_location("Item::SKU")
p Gadget.const_source_location(:SKU)
p Gadget.const_source_location(:VAT)
p Gadget.const_source_location(:SKU, false)
p Gadget.const_source_location(:TOP_LEVEL)
p Shop.const_source_location(:TOP_LEVEL)
p Shop.const_source_location(:TOP_LEVEL, false)
p Shop.const_source_location("::TOP_LEVEL")
p Object.const_source_location(:String)
p Shop.const_source_location(:MISSING)

m = Module.new
m.const_set :Foo, 1
p m.const_source_location(:Foo)
c = Class.new do
  eval('self::C = 1', nil, "given.rb", 100)
end
p c.const_source_location(:C)

Shop.autoload :Later, "/nonexistent/later.rb"
p Shop.const_source_location(:Later)

$VERBOSE = nil
Shop::MOVED = 5
Shop::MOVED = 6
p Shop.const_source_location(:MOVED)

["lower", "__X", "X=", "::", "Item::::SKU"].each do |n|
  Shop.const_source_location(n)
rescue NameError => e
  p e.message
end
[:"::TOP_LEVEL", :"Item::SKU"].each do |n|
  Shop.const_source_location(n)
rescue NameError => e
  p e.message
end
begin
  Shop.const_source_location("RATE::X")
rescue TypeError => e
  p e.message
end
p Shop.respond_to?(:const_source_location)
