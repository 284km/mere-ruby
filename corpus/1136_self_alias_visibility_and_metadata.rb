class SelfAliasOwn1136
  private
  def hidden = :hidden
  alias hidden hidden
  protected
  def guarded = :guarded
  alias guarded guarded
end
p [:own_visibility, SelfAliasOwn1136.private_method_defined?(:hidden),
   SelfAliasOwn1136.protected_method_defined?(:guarded)]

class SelfAliasParent1136
  private
  def below = :below
end
class SelfAliasPublic1136 < SelfAliasParent1136
  public :below
  alias below below
end
class SelfAliasProtected1136 < SelfAliasParent1136
  protected :below
  alias below below
end
class SelfAliasPrivate1136 < SelfAliasParent1136
  alias below below
end
p [:inherited_visibility, SelfAliasPublic1136.public_method_defined?(:below),
   SelfAliasProtected1136.protected_method_defined?(:below),
   SelfAliasPrivate1136.private_method_defined?(:below), SelfAliasPublic1136.new.below]

class SelfAliasHooks1136
  @events = []
  def self.method_added(name)
    @events << [name, instance_method(name).original_name]
  end
  def self.events = @events
  def value(x) = x + 1
  alias value value
  alias other value
  alias other other
end
p [:hooks, SelfAliasHooks1136.events]
object = SelfAliasHooks1136.new
before = object.method(:value)
location = before.source_location
SelfAliasHooks1136.class_eval { alias value value }
p [:reflection, before == object.method(:value), location == object.method(:value).source_location,
   object.method(:other).original_name, object.method(:other).arity, before.call(4)]

class SelfAliasClosure1136
  offset = 7
  define_method(:value) { |x| x + offset }
  alias value value
end
object = SelfAliasClosure1136.new
saved = object.method(:value)
SelfAliasClosure1136.class_eval { remove_method :value }
p [:closure_and_snapshot, saved.call(3), SelfAliasClosure1136.instance_methods(false).include?(:value)]

class SelfAliasSuperParent1136
  def voice = [:parent]
end
class SelfAliasSuperChild1136 < SelfAliasSuperParent1136
  def voice = [:child, super]
  alias voice voice
end
p [:super, SelfAliasSuperChild1136.new.voice]

module SelfAliasPrepend1136
  def voice = :prepended
end
class SelfAliasPrepended1136
  prepend SelfAliasPrepend1136
  def voice = :own
  alias voice voice
end
p [:prepended, SelfAliasPrepended1136.new.voice]
class SelfAliasString1136 < String
  alias length length
end
p [:builtin, SelfAliasString1136.new('abc').length]

class SelfAliasInitialize1136
  def initialize = nil
  public :initialize
  alias initialize initialize
end
p [:explicit_public_initializer, SelfAliasInitialize1136.public_method_defined?(:initialize)]

alias_warnings_1136 = []
Warning.define_singleton_method(:warn) { |message, **options| alias_warnings_1136 << message }
verbose_1136 = $VERBOSE
begin
  $VERBOSE = true
  eval("class SelfAliasWarning1136\n  def value = 1\n  alias value value\n  def value = 2\nend", nil, 'self-alias-warning.rb', 1)
ensure
  $VERBOSE = verbose_1136
end
p [:self_alias_redefinition_warnings, alias_warnings_1136.size]
