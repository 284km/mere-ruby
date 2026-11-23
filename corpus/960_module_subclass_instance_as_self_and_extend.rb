# An instance of a Module subclass is a module whose own class has methods.
# activerecord's enum builds `EnumMethods < Module`, includes an instance, and
# calls the subclass's private helper from inside the instance's module_eval:
#
#   _enum_methods_module.module_eval do
#     define_enum_methods(name, value_method_name, value, scopes, instance_methods)
#
# Here the instance's methods live in an anonymous module it stands for
# (mod_inst_backing). A module_eval body ran with that anonymous module as
# self, so `self.class` was Module and the subclass's methods were missing:
# every activerecord test whose models declare an enum stopped at load. And
# `extend` refused the instance ("expected Module"), where include took it.
class EM < Module
  def initialize(k) = (@k = k)
  def pub(x) = [:pub, x]
  def via_self = pub(9)
  private
    attr_reader :k
    def priv(x) = [:priv, x, k]
end
m = EM.new(:klass)
p m.pub(1), m.via_self, m.send(:priv, 4)
p m.module_eval { pub(1) }
p m.module_eval { priv(2) }
p m.instance_eval { priv(3) }
p m.class_eval { pub(5) }
p m.module_exec(6) { |v| [pub(v), self.class] }
p m.module_eval { [self == m, self.class, singleton_class.ancestors.include?(EM)] }
p m.module_eval { |mod| mod.equal?(m) }

# a def inside lands in the module, which include and extend both take
m.module_eval { def made = :made }
o = Object.new
p o.extend(m).made
c = Class.new { include m }
p c.new.made, m.instance_methods(false), c.include?(m)

# the enum shape, cut down
class Owner
  class Methods < Module
    def initialize(klass) = (@klass = klass)
    private
      attr_reader :klass
      def define_enum_methods(name, value)
        define_method("#{name}?") { @status == value }
        klass.send(:note, name)
      end
  end
  def self.note(n) = (@notes ||= []) << n
  def self.notes = @notes
  def self.methods_module = (@mm ||= Methods.new(self).tap { |mod| include mod })
  def self.enum(pairs)
    methods_module.module_eval do
      pairs.each { |name, value| define_enum_methods(name, value) }
    end
  end
  enum active: 0, archived: 1
  def initialize(s) = (@status = s)
end
p Owner.new(0).active?, Owner.new(1).archived?, Owner.new(0).archived?, Owner.notes

# An instance's own #initialize defines readers on itself, by a name computed
# at run time or written literally, with or without self. ActiveModel's
# SecurePassword builds its InstanceMethodsOnActivation that way; attr_reader
# was "undefined method" for the instance (and the literal form defined
# nothing), so every model with has_secure_password stopped at load.
class IM < Module
  def initialize(a, how)
    case how
    when 1 then self.attr_reader a
    when 2 then send(:attr_reader, a)
    when 3 then attr_reader a
    when 4 then attr_reader :lit
    when 5 then attr_accessor a
    when 6 then attr_writer a
    end
    define_method("#{a}_set") { |v| instance_variable_set("@#{a}", v) }
  end
end
(1..6).each { |h| p [h, IM.new(:x, h).instance_methods.sort] }
k = Class.new { include IM.new(:password, 5) }
o = k.new
o.password = 3
p o.password

# Module's other methods, private ones included, reach the module from the
# instance's module_eval: Rails' undefine_attribute_methods runs
# `module_eval { undef_method(*instance_methods) }` on one.
class GM < Module
  def initialize = super
end
g = GM.new
g.module_eval { def a = 1; def b = 2; def c = 3; def d = 4 }
g.module_eval { undef_method(:a); alias_method :e, :b; remove_method :c }
p g.instance_methods.sort
class GA < Module
  def initialize
    module_eval { def q = 1 }
    module_eval { undef_method(*instance_methods) }
  end
end
p GA.new.instance_methods
gen = GM.new
gen.module_eval { def title = 1; def body = 2 }
gen.module_eval { undef_method(*instance_methods) }
p Class.new { include gen }.new.respond_to?(:title), gen.instance_methods

# the subclass's own attr_reader wins over Module's; attr_accessor still defines
class OA < Module
  def attr_reader(*a) = (@seen ||= []).concat(a)
  def initialize
    attr_reader :z
    attr_accessor :w
  end
  def seen = @seen
end
o = OA.new
p o.seen, o.instance_methods.sort, o == o, o.frozen?

# a def in the instance's module_eval goes to the instance, not the subclass
m2 = GM.new
p m2.module_eval { [self.equal?(m2), (def made2 = :made)] }, m2.instance_methods, GM.instance_methods(false)

# a frozen instance refuses every change that would land in its module, by
# a call or from its module_eval, and names the instance as ruby does
class FM < Module; end
fm = FM.new
fm.module_eval { def a = 1; def b = 2 }
fm.freeze
[[:attr_reader, :x], [:attr_writer, :x], [:attr_accessor, :x], [:attr, :x], [:alias_method, :c, :a],
 [:remove_method, :a], [:undef_method, :b], [:define_method, :d, -> {}], [:public, :a], [:private, :a]].each do |n, *a|
  begin
    fm.send(n, *a); p [n, :ok]
  rescue => e
    p [n, e.class, e.message.sub(/0x\h+/, "X")]
  end
end
begin; fm.module_eval { def e = 1 }; p :def_ok; rescue => e; p [:def, e.class, e.message.sub(/0x\h+/, "X")]; end
begin; fm.module_eval { attr_reader :y }; p :blk_ok; rescue => e; p [:blk, e.class, e.message.sub(/0x\h+/, "X")]; end
p fm.instance_methods(false).sort
# ...and one frozen before its module was ever made
fz = FM.new.freeze
begin; fz.module_eval { def f = 1 }; rescue => e; p [e.class, e.message.sub(/0x\h+/, "X")]; end
