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
