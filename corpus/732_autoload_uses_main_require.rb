require 'tmpdir'
Dir.mktmpdir('method-autoload') do |directory|
  File.write(File.join(directory, 'events.rb'), 'module MethodAutoloadOwner; module Plugin; module Events; READY = :ready; end; end; end')
  module MethodAutoloadOwner
    module Plugin; end
    class Runtime
      def require(*groups)
        Plugin::Events::READY
      end
    end
  end
  MethodAutoloadOwner::Plugin.autoload(:Events, File.join(directory, 'events.rb'))
  begin
    p [:method, MethodAutoloadOwner::Runtime.new.require(:default)]
  rescue NameError => error
    p [:method_error, error.class, error.message]
  end
  p [:pending, MethodAutoloadOwner::Plugin.autoload?(:Events).nil?]
  p [:direct, MethodAutoloadOwner::Plugin::Events::READY]
end

kernel_loader = Kernel.method(:require)
main_receiver = self
seen = []
define_singleton_method(:require) do |path|
  seen << [equal?(main_receiver), File.basename(path)]
  kernel_loader.call(path)
end
Dir.mktmpdir('main-autoload') do |directory|
  File.write(File.join(directory, 'feature.rb'), 'module MainRequireAutoload; READY = :ready; end')
  module MainRequireAutoload; end
  MainRequireAutoload.autoload(:READY, File.join(directory, 'feature.rb'))
  p [:main_override, MainRequireAutoload::READY]
end
singleton_class.remove_method(:require)
p [:main_calls, seen]
