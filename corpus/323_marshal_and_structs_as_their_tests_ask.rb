# Marshal and Struct as test_marshal and test_struct ask them (note 345).
def t(name)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message[0, 70]}"; end
  puts "#{name}: #{r}"
end

# a class defined inside a singleton class is anonymous, not a singleton
o = Object.new
c = class << o; class C; self; end; end
t(:sng_nested) { [c.singleton_class?, o.singleton_class.singleton_class?] }
t(:dump_nested) { begin; Marshal.dump(c); rescue TypeError => e; e.message[/\Acan.t dump anonymous class/]; end }
t(:dump_env) { Marshal.dump(ENV) }

# a Range subclass that is its own begin and end
class CyclicRange < Range; def <=>(other); true; end; end
r = CyclicRange.allocate
r.instance_eval { initialize(r, r) }
t(:cyclic) { r2 = Marshal.load(Marshal.dump(r)); [r2.begin.equal?(r2), r2.end.equal?(r2), r2.class] }

# a constant that is no class, and a class with no _load / _load_data
class C3; def _dump(s) = "foo"; end
m = Marshal.dump(C3.new)
Object.send(:remove_const, :C3)
C3 = nil
t(:not_class) { Marshal.load(m) }
cu = Class.new(Time)
Object.const_set(:Unloadable, cu)
cu.class_eval { alias _dump_data _dump; undef _dump }
t(:no_load_data) { Marshal.load(Marshal.dump(cu.new(2000))) }
cd = Class.new(Time)
Object.const_set(:Userdef, cd)
class << cd; undef _load; end
t(:no_load) { Marshal.load(Marshal.dump(cd.new(2000))) }
t(:respond) { [Time.respond_to?(:_load), Time.respond_to?(:_load, true), cd.respond_to?(:_load, true)] }

# marshal_load and the data's ivars
class LoadData
  attr_reader :data
  def initialize(data) = @data = data
  alias marshal_dump data
  alias marshal_load initialize
end
class FrozenLoad < LoadData
  def initialize(*) = (super; freeze)
  alias marshal_load initialize
end
s = +"data"
s.instance_variable_set(:@t, 42)
t(:copy_ivar) { v = Marshal.load(Marshal.dump(LoadData.new(s))); v.instance_variable_get(:@t) }
t(:frozen_load) { begin; Marshal.load(Marshal.dump(FrozenLoad.new(s))); rescue FrozenError => e; e.class; end }

# a child's marshal_dump that removes its parent's ivar
class Parent
  attr_accessor :kid, :baz
end
class Kid
  attr_accessor :up
  def marshal_dump = (up.remove_instance_variable(:@baz) if up.baz; { up: up })
  def marshal_load(d) = self.up = d[:up]
end
pa = Parent.new
pa.kid = Kid.new
pa.kid.up = pa
pa.baz = :kept
t(:snapshot) { Marshal.load(Marshal.dump(pa)).baz }

# the ruby2_keywords flag
ruby2_keywords def r2h(*a) = a.last
def r2t(key: 1) = key
d = Marshal.dump(r2h(key: 42))
t(:r2k_dump) { d }
t(:r2k_load) { r2t(*[Marshal.load(d)]) }
t(:r2k_other) { r2t(*[Marshal.load(d.sub(/\x06K(?=T\z)/, "\x08KEY"))]) }

# reading ahead from an IO-like source
input = Struct.new(:bytes, :used) do
  def initialize = super("\x04\x08[\x07".bytes, false)
  def getbyte = bytes.shift
  def read(_len, _outbuf = nil) = (return nil if used; self.used = true; "0" * 4096)
end
t(:overread) { Marshal.load(input.new) }

# a regex interpolates a variable without braces, and \# keeps it text
@sv = "S"
$gv = "G"
x = 1
t(:rx_dvar) { [/a #@sv b/.source, %r{#$gv}.source, /\#{x}#{x}/.source, /\#@sv/.source] }

# Struct: setter parameters, a member that is no local's name, the warning
k = Struct.new(:a)
t(:params) { [k.instance_method(:a).parameters, k.instance_method(:a=).parameters] }
ka = Struct.new(:@a, :b)
oa = ka.new(1, 2)
t(:at_member) { [oa.__send__(:@a), oa.inspect, oa.to_h, oa.to_a] }
oa.__send__(:"@a=", 3)
t(:at_set) { oa.inspect }
module TS; class Sub; SubStruct = Class.new(Struct); end; end
$stderr = $stdout
$VERBOSE = true
TS::Sub::SubStruct.new("RX")
TS::Sub::SubStruct.new("RX")
$VERBOSE = false
