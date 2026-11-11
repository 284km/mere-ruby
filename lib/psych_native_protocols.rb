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
        SAME_OBJECT = BasicObject.instance_method(:equal?)

        def initialize
          @obj_to_id = {}
          @obj_to_node = {}
          @unboxed_ids = {}.compare_by_identity
          @unboxed_nodes = {}.compare_by_identity
          @counter = 0
        end

        def register(target, node)
          key = IDENTITY.bind(target).call
          if key == 0
            @unboxed_nodes[target] = [target, node]
          elsif entry = entry_for(@obj_to_node, key, target)
            entry[1] = node
          else
            @obj_to_node[key] = [target, node, @obj_to_node[key]]
          end
        end

        def key?(target)
          key = IDENTITY.bind(target).call
          key == 0 ? @unboxed_nodes.key?(target) : !!entry_for(@obj_to_node, key, target)
        end

        def id_for(target)
          key = IDENTITY.bind(target).call
          table = key == 0 ? @unboxed_ids : @obj_to_id
          entry = key == 0 ? table[target] : entry_for(table, key, target)
          unless entry
            @counter += 1
            if key == 0
              table[target] = entry = [target, @counter]
            else
              table[key] = entry = [target, @counter, table[key]]
            end
          end
          entry[1]
        end

        def node_for(target)
          key = IDENTITY.bind(target).call
          (key == 0 ? @unboxed_nodes[target] : entry_for(@obj_to_node, key, target))[1]
        end

        private

        # Numeric IDs from different native value stores can overlap. Keep the
        # indexed lookup, but resolve collisions by actual, unoverridden identity.
        # Each entry retains its target for the entire visitor lifetime.
        def entry_for(table, key, target)
          entry = table[key]
          while entry
            return entry if SAME_OBJECT.bind(entry[0]).call(target)
            entry = entry[2]
          end
          nil
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
