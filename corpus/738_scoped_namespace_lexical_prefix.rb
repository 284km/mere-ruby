module NamespaceReviewRoot; module Branch; end; end
module NamespaceReviewScope
  module NamespaceReviewRoot; module Branch; end; end
  class NamespaceReviewRoot::Branch::Child; end
end
p [:class, NamespaceReviewScope::NamespaceReviewRoot::Branch.const_defined?(:Child, false), NamespaceReviewRoot::Branch.const_defined?(:Child, false)]
module ModuleReviewRoot; module Branch; end; end
module ModuleReviewScope
  module ModuleReviewRoot; module Branch; end; end
  module ModuleReviewRoot::Branch::Child; end
end
p [:module, ModuleReviewScope::ModuleReviewRoot::Branch.const_defined?(:Child, false), ModuleReviewRoot::Branch.const_defined?(:Child, false)]
module ConditionalReviewRoot; module Branch; end; end
module ConditionalReviewScope
  module ConditionalReviewRoot; module Branch; end; end
  if true
    class ConditionalReviewRoot::Branch::Child; end
  end
end
p [:conditional, ConditionalReviewScope::ConditionalReviewRoot::Branch.const_defined?(:Child, false), ConditionalReviewRoot::Branch.const_defined?(:Child, false)]
module NamespaceReviewScope
  class ::NamespaceReviewRoot::Branch::Absolute; end
end
p [:root, NamespaceReviewScope::NamespaceReviewRoot::Branch.const_defined?(:Absolute, false), NamespaceReviewRoot::Branch.const_defined?(:Absolute, false)]
module AliasReviewRoot; module Branch; end; end
AliasReviewName = AliasReviewRoot
module AliasReviewScope
  module Actual; module Branch; end; end
  AliasReviewName = Actual
  class AliasReviewName::Branch::Child; end
end
p [:alias, AliasReviewScope::Actual::Branch.const_defined?(:Child, false), AliasReviewRoot::Branch.const_defined?(:Child, false)]
require 'tmpdir'
module AutoloadReviewRoot; module Branch; end; end
module AutoloadReviewScope; end
Dir.mktmpdir('scoped-review') do |directory|
  path = File.join(directory, 'parent.rb')
  File.write(path, 'module AutoloadReviewScope; module AutoloadReviewRoot; module Branch; end; end; end')
  AutoloadReviewScope.autoload(:AutoloadReviewRoot, path)
  AutoloadReviewScope.module_eval('class AutoloadReviewRoot::Branch::Child; end')
  p [:autoload, AutoloadReviewScope::AutoloadReviewRoot::Branch.const_defined?(:Child, false), AutoloadReviewRoot::Branch.const_defined?(:Child, false)]
end
