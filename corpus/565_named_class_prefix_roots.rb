path = "/tmp/mere-named-prefix-gc-#{Process.pid}.rb"
begin
  File.write(path, <<~CODE)
    class AnonClass_User
      def answer; 81; end
    end
    module AnonModule_User
      Answer = 82
    end
    class Struct_User
      def answer; 83; end
    end
    module Refine_User
      Answer = 84
    end
  CODE
  load path
  4.times { GC.start }
  raise 'named class lost' unless Object.const_get('AnonClass_' + 'User').new.answer == 81
  raise 'named module lost' unless Object.const_get('AnonModule_' + 'User').const_get(:Answer) == 82
  raise 'named Struct-prefix class lost' unless Object.const_get('Struct_' + 'User').new.answer == 83
  raise 'named Refine-prefix module lost' unless Object.const_get('Refine_' + 'User').const_get(:Answer) == 84
  %w[AnonClass_User AnonModule_User Struct_User Refine_User].each do |name|
    raise 'named prefix hidden' unless Object.const_get(name).name == name
  end
  raise 'named class kind changed' unless Object.const_get('AnonClass_' + 'User').class == Class
  named_refine = Object.const_get('Refine_' + 'User')
  raise 'named module kind changed' unless named_refine.class == Module
  named_refine.include(Module.new)
  named_refine.prepend(Module.new)
  puts 'named prefix roots preserved'
ensure
  File.delete(path) if File.exist?(path)
end
