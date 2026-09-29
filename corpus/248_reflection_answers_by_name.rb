# Reflection reached BY NAME answers what the syntax answers.

# ---- 1. Kernel's functions are methods: send, method, a receiver ----------
send(:puts, "by send")
p send(:format, "%03d", 7)
p Object.new.send(:send, :format, "%d", 1)
p method(:format).call("%s!", "m")
begin
  Object.new.puts "x"
rescue NoMethodError => e
  p e.message.start_with?("private method 'puts' called")
end
p 3.then.class, 3.then.size

# ---- 2. a method added to a singleton class tells the attached object ------
$seen = []
class Hooked
  def self.singleton_method_added(n) = ($seen << n unless n == :singleton_method_added)
  def self.a; end
  class << self
    def b; end
    attr_reader :c
    alias_method :d, :b
  end
end
p $seen

# ---- 3. the default visibility belongs to the scope -----------------------
m = Module.new do
  send :private
  def hidden; end
  1.times { public }
  def shown; end
end
p [m.private_instance_methods(false), m.public_instance_methods(false)]

# ---- 4. const_get's inherit flag and path rules ---------------------------
TOP_CONST = :top
module Outer
  class Base; IN_BASE = 1; end
  class Kid < Base; end
end
p Outer::Kid.const_get(:IN_BASE)
[-> { Outer::Kid.const_get(:IN_BASE, false) },
 -> { Object.const_get("Outer::TOP_CONST") },
 -> { Outer.const_get(:"Kid::IN_BASE") }].each do |f|
  f.call
rescue NameError => e
  p [e.class, e.name]
end
p Outer.const_get("::TOP_CONST")

# ---- 5. a class copy is a copy --------------------------------------------
Copy = Outer::Base.dup
p [Copy.name, Copy.const_get(:IN_BASE), Copy.equal?(Outer::Base)]

# ---- 6. const_added hears class and module definitions --------------------
$added = []
module Watch
  def self.const_added(n) = $added << n
  class Inner; end
  module Deep; end
  X = 1
end
p $added

# ---- 7. defined? asks what ruby asks --------------------------------------
class CvHolder
  def t
    @@cv = 1
    defined?(@@cv)
  end
end
p CvHolder.new.t
def yielder = yield
def asks = yielder { defined?(yield) }
p asks { }
