require 'tmpdir'
module RootedBranch; end
class Object::RootedBranch::AddedClass; end
module Object::RootedBranch::AddedModule; end
module NestedDefinition
  class Object::RootedBranch::NestedClass; end
  module Object::RootedBranch::NestedModule; end
  if true
    class Object::RootedBranch::ConditionalClass; end
    module Object::RootedBranch::ConditionalModule; end
  end
end
p RootedBranch.constants(false).sort
class NamespaceParent
  Branch = Module.new
end
class NamespaceChild < NamespaceParent; end
class NamespaceChild::Branch::AddedClass; end
module NamespaceChild::Branch::AddedModule; end
p NamespaceParent::Branch.constants(false).sort
module NamespaceHook
  Actual = Module.new
  Actual.const_set(:Branch, Module.new)
  def self.const_missing(name)
    ($namespace_hook_calls ||= []) << name
    name == :Alias ? Actual : super
  end
end
class NamespaceHook::Alias::Branch::AddedClass; end
if true
  module NamespaceHook::Alias::Branch::AddedModule; end
end
p [NamespaceHook::Actual::Branch.constants(false).sort, $namespace_hook_calls]
Dir.mktmpdir('scoped-namespace-tail') do |directory|
  path = File.join(directory, 'namespace.rb')
  File.write(path, 'module NamespaceAutoload; module Branch; end; end')
  module NamespaceAutoload; end
  NamespaceAutoload.autoload(:Branch, path)
  class NamespaceAutoload::Branch::AddedClass; end
  module NamespaceAutoload::Branch::AddedModule; end
  p NamespaceAutoload::Branch.constants(false).sort
end
module NamespacePrivate
  Branch = Module.new
  private_constant :Branch
end
begin
  class NamespacePrivate::Branch::Added; end
rescue => error
  p [:private, error.class]
end
module NamespaceNotModule
  Branch = 6
end
begin
  module NamespaceNotModule::Branch::Added; end
rescue => error
  p [:not_module, error.class]
end
