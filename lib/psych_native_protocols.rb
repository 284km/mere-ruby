module Psych
  # The public compatibility level; parsing and emitting use the Ruby backend.
  def self.libyaml_version
    [0, 2, 5]
  end

  class ClassLoader
    private

    # rb_path_to_class resolves namespaces without const_missing or inheritance.
    def path2class(path)
      raise ArgumentError, 'invalid class path encoding (non ASCII)' unless path.encoding.ascii_compatible?
      if path.empty? || path.start_with?('#')
        raise ArgumentError, "can't retrieve anonymous class #{path.inspect}"
      end
      value = Object
      names = path.split('::', -1)
      names.pop if names.last == ''
      names.each do |name|
        unless !name.empty? && value.const_defined?(name, false)
          raise ArgumentError, "undefined class/module #{path}"
        end
        value = value.const_get(name, false)
        raise TypeError, "#{path} does not refer to class/module" unless Module === value
      end
      value
    rescue NameError
      raise ArgumentError, "undefined class/module #{path}"
    end
  end

  module Visitors
    class YAMLTree
      class Registrar
        IDENTITY = BasicObject.instance_method(:__id__)

        def initialize
          @obj_to_id = {}
          @obj_to_node = {}
          @unboxed_ids = {}.compare_by_identity
          @unboxed_nodes = {}.compare_by_identity
          @counter = 0
        end

        def register(target, node)
          key = IDENTITY.bind(target).call
          table = key == 0 ? @unboxed_nodes : @obj_to_node
          table[key == 0 ? target : key] = [target, node]
        end

        def key?(target)
          key = IDENTITY.bind(target).call
          key == 0 ? @unboxed_nodes.key?(target) : @obj_to_node.key?(key)
        end

        def id_for(target)
          key = IDENTITY.bind(target).call
          table = key == 0 ? @unboxed_ids : @obj_to_id
          key = target if key == 0
          entry = table[key]
          unless entry
            @counter += 1
            table[key] = entry = [target, @counter]
          end
          entry[1]
        end

        def node_for(target)
          key = IDENTITY.bind(target).call
          (key == 0 ? @unboxed_nodes[target] : @obj_to_node[key])[1]
        end
      end
    end

    class ToRuby
      private

      def build_exception(klass, message)
        value = klass.allocate
        ::Exception.instance_method(:initialize).bind(value).call(message)
        value
      end
    end
  end
end
