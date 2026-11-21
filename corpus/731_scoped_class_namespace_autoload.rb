require 'tmpdir'
Dir.mktmpdir('scoped-autoload') do |directory|
  File.write(File.join(directory, 'base.rb'), 'module RootAutoload; class Base; end; end')
  File.write(File.join(directory, 'child.rb'), 'module RootAutoload; class Base::Child < Base; end; end')
  module RootAutoload
  end
  RootAutoload.autoload(:Base, File.join(directory, 'base.rb'))
  require File.join(directory, 'child.rb')
  p [:autoload_scoped, RootAutoload::Base.const_defined?(:Child, false)]
  p [:root_leak, Object.const_defined?(:Base, false), Object.const_defined?(:Child, false)]
  p [:owner_constants, RootAutoload.constants(false).sort]
end

module RootPlain
  class Base; end
  class Base::Child < Base; end
end
p [:plain_scoped, RootPlain::Base.const_defined?(:Child, false)]

Dir.mktmpdir('scoped-autoload-eval') do |directory|
  File.write(File.join(directory, 'base.rb'), 'module RootAutoloadEval; class Base; end; end')
  module RootAutoloadEval; end
  RootAutoloadEval.autoload(:Base, File.join(directory, 'base.rb'))
  RootAutoloadEval.module_eval('class Base::Child; end')
  p [:eval_scoped, RootAutoloadEval::Base.const_defined?(:Child, false)]
end

Dir.mktmpdir('scoped-autoload-outer') do |directory|
  File.write(File.join(directory, 'base.rb'), 'module RootAutoloadOuter; class Base; end; end')
  module RootAutoloadOuter; module Inner; end; end
  RootAutoloadOuter.autoload(:Base, File.join(directory, 'base.rb'))
  module RootAutoloadOuter
    module Inner
      class Base::Child < Base; end
    end
  end
  p [:outer_scoped, RootAutoloadOuter::Base.const_defined?(:Child, false)]
end

module SelfScopedClassControl
  SelfScopedClassControl = Module.new
  class self::Child; end
end
p [:self_namespace, SelfScopedClassControl.const_defined?(:Child, false), SelfScopedClassControl::SelfScopedClassControl.const_defined?(:Child, false)]
module LocalScopedClassControl
  LocalScopedClassControl = Module.new
  owner = self
  class owner::Child; end
end
p [:local_namespace, LocalScopedClassControl.const_defined?(:Child, false), LocalScopedClassControl::LocalScopedClassControl.const_defined?(:Child, false)]
