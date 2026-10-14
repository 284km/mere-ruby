# Marshal as CRuby's test_marshal asks it (note 328): under freeze: true a
# String with ivars or modules is frozen where it is and keeps them, and
# only a bare one is shared; a Regexp with no encoding ivar drops the
# backslash 1.8 did not have; a module prepended to a singleton class comes
# back prepended; Encoding and NameError#name survive the trip; and the
# Range and Regexp subclasses that initialize through super are a Range
# and a Regexp.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message}"; end
  puts "#{n}: #{r.gsub(/0x\h+/, '0x')}"
end
module M306; end
class S306 < String; def initialize(v, *a) super(*a); @v = v; end; end
F = ->(s) { Marshal.load(s, freeze: true) }
t(1) { o = +""; o.instance_eval { @iv = 1 }; x = F.(Marshal.dump(o)); [x.instance_variables, x.frozen?] }
t(2) { o = +""; o.extend M306; x = F.(Marshal.dump(o)); [x.kind_of?(M306), x.frozen?] }
t(3) { s = S306.new(10, "b"); s.instance_eval { @v = s }; o = F.(Marshal.dump(s)); [o.class, o.equal?(o.instance_eval { @v })] }
t(4) { s = +"test"; s.instance_variable_set(:@self, s); o = F.(Marshal.dump([s, s])); [o[0].equal?(o[1]), o[0].equal?(o[0].instance_variable_get(:@self))] }
t(5) { o = F.(Marshal.dump(["x", "x"])); [o[0].equal?(o[1]), o[0].frozen?] }
t(6) { [Marshal.load("\004\b/\fa\\u3042\000").source, Marshal.load(Marshal.dump(/aあ/)).source] }
class O306; def initialize(v) @v = v end; end
t(7) { o = O306.new(1); o.singleton_class.class_eval { prepend M306 }; d = Marshal.dump(o); [d, Marshal.load(d).singleton_class.ancestors.take(3).map { |m| m.singleton_class? ? :sc : m }] }
t(8) { [Marshal.load(Marshal.dump(Encoding::EUC_JP)), Marshal.dump(Encoding::UTF_8)] }
t(9) { e = Marshal.load(Marshal.dump(NoMethodError.new("x", :nm306, [1]))); [e.name, e.args] }
class R306 < Range; attr_reader :foo; def initialize(a, b) super; @foo = 1; end; end
t(10) { r = R306.new(1, 3); [r, r.first, r.to_a, r == (1..3), r === 2, r.size, r.foo, Marshal.load(Marshal.dump(r)).foo] }
class X306 < Regexp; def initialize(v, *a) super(*a); @v = v; end; end
t(11) { x = X306.new(10, "a", "i"); [x, x =~ "bA", "bA" =~ x, x == X306.new(10, "a", "i"), x === "A", x.options] }
class C306 < Range; def <=>(o) = 0; end
t(12) { o = C306.allocate; o.instance_eval { initialize(o, 1) }; [o.inspect, (o.send(:initialize, 1, 2) rescue $!.class)] }
t(13) { o = Object.new; c = class << o; class K306; self; end; end; Marshal.dump(c) rescue $!.class }
t(14) { Marshal.load("\x04\be:\x0F\x00omparableo:\vObject\x00") rescue [$!.class, $!.message.start_with?("undefined class/module")] }
