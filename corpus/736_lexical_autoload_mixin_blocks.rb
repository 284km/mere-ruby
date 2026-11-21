require 'tmpdir'
module LexicalMixinSource
  module Feature
    def feature; :lexical; end
  end
  BLOCK=proc { include Feature }
end
receiver=Class.new
receiver.class_eval(&LexicalMixinSource::BLOCK)
begin
 p [:ordinary, receiver.new.feature, receiver.ancestors.include?(LexicalMixinSource::Feature)]
rescue => error
 p [:ordinary,error.class]
end
Dir.mktmpdir('lexical-mixin') do |directory|
 File.write(File.join(directory,'feature.rb'), 'module AutoloadMixinSource; module Feature; def feature; :autoload; end; end; end')
 module AutoloadMixinSource; end
 AutoloadMixinSource.autoload(:Feature, File.join(directory,'feature.rb'))
 AutoloadMixinSource.module_eval('BLOCK=proc { include Feature }')
 receiver=Class.new
 receiver.class_eval(&AutoloadMixinSource::BLOCK)
 begin
  p [:autoload,receiver.new.feature,receiver.ancestors.include?(AutoloadMixinSource::Feature)]
 rescue => error
  p [:autoload,error.class]
 end
end

module MixinLexicalShadow
  module Feature
    def selected; :lexical; end
  end
  BLOCK=proc { prepend Feature }
end
class MixinShadowReceiver
  module Feature
    def selected; :receiver; end
  end
end
MixinShadowReceiver.class_eval(&MixinLexicalShadow::BLOCK)
p [:shadow, MixinShadowReceiver.new.selected]
module MixinAliasSource
  Real = Module.new { def selected; :alias; end }
  Alias = Real
  BLOCK=proc { include Alias }
end
alias_receiver = Class.new
alias_receiver.class_eval(&MixinAliasSource::BLOCK)
p [:alias, alias_receiver.new.selected, alias_receiver.ancestors.include?(MixinAliasSource::Real)]
module MixinInvalidSource
  Invalid = 7
  BLOCK=proc { include Invalid }
end
begin
  Class.new.class_eval(&MixinInvalidSource::BLOCK)
rescue => error
  p [:invalid, error.class]
end

require 'tmpdir'
module ParentAutoloadRoot
  module Feature
    module Item
      def selected; :outer; end
    end
  end
  module Inner
    class Host; end
  end
end
Dir.mktmpdir('parent-autoload') do |directory|
 path=File.join(directory,'feature.rb')
 File.write(path, 'module ParentAutoloadRoot; module Inner; module Feature; module Item; def selected; :inner; end; end; end; end; end')
 ParentAutoloadRoot::Inner.autoload(:Feature,path)
 module ParentAutoloadRoot
  module Inner
   class Host
    include Feature::Item
   end
  end
 end
 p [:included,ParentAutoloadRoot::Inner::Host.new.selected]
end

module RuntimeArgumentFeature
  def runtime_argument; :argument; end
  module Nested
    def nested_argument; :nested; end
  end
end
class MethodArgumentReceiver
  def self.selected_module; RuntimeArgumentFeature; end
  include selected_module
end
p [:method_argument,MethodArgumentReceiver.new.runtime_argument]
ivar_receiver=Class.new
ivar_receiver.instance_variable_set(:@selected_module,RuntimeArgumentFeature)
ivar_receiver.class_eval { include @selected_module }
p [:ivar_argument,ivar_receiver.new.runtime_argument]
class ClassVariableArgumentReceiver
  @@selected_module=RuntimeArgumentFeature
  include @@selected_module
end
p [:class_variable_argument,ClassVariableArgumentReceiver.new.runtime_argument]
class NamespaceArgumentReceiver
  def self.selected_namespace; RuntimeArgumentFeature; end
  include selected_namespace::Nested
end
p [:method_namespace,NamespaceArgumentReceiver.new.nested_argument]
class RuntimeArgumentFactory < Module
  def initialize
    define_method(:generated) { :generated }
  end
end
generated_receiver=Class.new
generated_receiver.instance_variable_set(:@generated,RuntimeArgumentFactory.new)
generated_receiver.class_eval { include @generated }
p [:module_instance_argument,generated_receiver.new.generated]
class OverrideArgumentReceiver
  @selected_argument=9
  def self.include(value); @received=value; end
  include @selected_argument
  def self.received; @received; end
end
p [:override_argument,OverrideArgumentReceiver.received]

# Scope segments supplied by real const_missing hooks are evaluated once.
module HookedMixinPath
  Real = Module.new { def hooked_mixin; :hooked; end }
  Namespace = Module.new
  Namespace.const_set(:Feature, Real)
  def self.const_missing(name)
    ($mixin_scope_calls ||= []) << name
    name == :Alias ? Namespace : super
  end
end
class HookedMixinReceiver
  include HookedMixinPath::Alias::Feature
end
p [:hooked_scope, HookedMixinReceiver.new.hooked_mixin, $mixin_scope_calls]
module InheritedMixinPath
  Feature = Module.new { def inherited_mixin; :inherited; end }
end
class InheritedMixinNamespace
  include InheritedMixinPath
end
class InheritedMixinReceiver
  include InheritedMixinNamespace::Feature
end
p [:inherited_scope, InheritedMixinReceiver.new.inherited_mixin]
TopOnlyMixin = Module.new
module MissingMixinNamespace; end
begin
  Class.new { include MissingMixinNamespace::TopOnlyMixin }
rescue => error
  p [:missing_scope, error.class]
end
module PrivateMixinNamespace
  Feature = Module.new
  private_constant :Feature
end
begin
  Class.new { include PrivateMixinNamespace::Feature }
rescue => error
  p [:private_scope, error.class]
end

# Object:: uses the same bare autoload key as a top-level constant.
Dir.mktmpdir('object-mixin-autoload') do |directory|
  %w[Block ClassBody Prepend].each do |kind|
    name = "ObjectMixinAutoload#{kind}"
    path = File.join(directory, "#{kind}.rb")
    File.write(path, "module #{name}; def object_mixin_value; :#{kind.downcase}; end; end")
    Object.autoload(name, path)
    receiver = Class.new
    if kind == 'Block'
      receiver.class_eval { include Object::ObjectMixinAutoloadBlock }
    elsif kind == 'ClassBody'
      Object.const_set(:ObjectMixinAutoloadReceiver, receiver)
      eval('class ObjectMixinAutoloadReceiver; include Object::ObjectMixinAutoloadClassBody; end')
    else
      receiver.class_eval { prepend Object::ObjectMixinAutoloadPrepend }
    end
    p [:object_mixin_autoload, kind, receiver.new.object_mixin_value, Object.autoload?(name)]
  end
end
