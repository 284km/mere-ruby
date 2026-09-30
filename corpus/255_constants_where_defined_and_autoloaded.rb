# A constant knows where it was defined: Module#const_source_location answers
# [file, line] for an assignment, a `class`/`module` keyword, const_set and an
# eval with a given file and line; [] for one the interpreter defined itself;
# nil for none. The name follows const_get's rules (a Symbol is one constant,
# a String may be a path, `inherit` governs the first segment only), and the
# last segment is only looked at -- an autoload not yet loaded answers where
# `autoload` was called.
#
# An autoload is a constant before its file runs (const_defined?, constants,
# defined? -- none of which load it), stays registered when its file raises,
# is spent when the file ran without defining it, and is loaded first when a
# `class`/`module` keyword opens its name. A deprecated constant warns on
# every read; a private one is closed to `::X` and to `A::X` written inside a
# module that includes A.

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

require "tmpdir"
Dir.mktmpdir do |dir|
  File.write(File.join(dir, "lib_a.rb"), "module Shop\n  LibA = :loaded\nend\n")
  File.write(File.join(dir, "raises.rb"), "$raised = ($raised || 0) + 1\nraise 'boom'\n")
  File.write(File.join(dir, "empty.rb"), "# defines nothing\n")
  File.write(File.join(dir, "reopen.rb"), "module Shop\n  class Opened\n    def from_file; :file; end\n  end\nend\n")
  $LOAD_PATH.unshift dir

  Shop.autoload :LibA, "lib_a"
  p Shop.const_defined?(:LibA, false)
  p Shop.constants.include?(:LibA)
  p defined?(Shop::LibA)
  p Shop.const_source_location(:LibA) == [__FILE__, __LINE__ - 4]
  p Shop::LibA
  p Shop.autoload?(:LibA)
  p Shop.const_source_location(:LibA)[1]

  Shop.autoload :Boom, "raises"
  2.times do
    Shop::Boom
  rescue RuntimeError => e
    p [e.message, $raised, Shop.autoload?(:Boom)]
  end
  p Shop.const_defined?(:Boom)

  Shop.autoload :Nothing, "empty"
  begin
    Shop::Nothing
  rescue NameError => e
    p e.message
  end
  p [Shop.autoload?(:Nothing), Shop.const_defined?(:Nothing)]

  Shop.autoload :Opened, "reopen"
  module Shop
    class Opened
      def here; :here; end
    end
  end
  p [Shop::Opened.new.from_file, Shop::Opened.new.here]
  $LOAD_PATH.shift
end

# a constant holding an anonymous class is reopened as that class
Shop::Anon = Class.new
module Shop
  class Anon
    def y; :y; end
  end
end
p Shop::Anon.new.y

Warning[:deprecated] = true
$VERBOSE = false
module Shop
  OLD = 1
  deprecate_constant :OLD
end
p Shop::OLD
p Shop.const_get(:OLD)
begin
  Shop.deprecate_constant :NEVER
rescue NameError => e
  p e.message
end

class Object
  HIDDEN_TOP = 1
  private_constant :HIDDEN_TOP
end
begin
  ::HIDDEN_TOP
rescue NameError => e
  p e.message
end
p defined?(::HIDDEN_TOP)
p HIDDEN_TOP
module Shop
  module Secret
    KEY = 1
    private_constant :KEY
  end
  module User
    include Secret
    def self.k = Secret::KEY
  end
end
begin
  Shop::User.k
rescue NameError => e
  p e.message
end

@holder = Module.new
@holder::SET_THROUGH_AN_IVAR = 1
p @holder::SET_THROUGH_AN_IVAR
named = Module.new
def named.name = "Named"
begin
  named::NOPE
rescue NameError => e
  p e.message
end
