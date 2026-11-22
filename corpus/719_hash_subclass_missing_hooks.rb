class Options < Hash
  def method_missing(name, *args, **keywords, &block)
    if name.end_with?("=")
      self[name.to_s.chomp("=").to_sym] = args.fetch(0)
    elsif name == :dynamic
      [args, keywords, block&.call]
    else
      self[name]
    end
  end
  def respond_to_missing?(name, include_private = false)
    true
  end
  def real
    :real
  end
  alias native_size size
  alias native_fetch fetch
end
class ChildOptions < Options; end
h = ChildOptions.new
h.title = "value"
p [h.class, h.title, h[:title], h.real]
p h.dynamic(1, flag: 2) { :block }
p [h.respond_to?(:dynamic), h.size, h.native_size, h.keys]
p h.native_fetch(:title)
p h.native_fetch(:absent) { h.dynamic(3, from: :native) { :callback } }
module DynamicRefinement
  refine Options do
    def dynamic(*args)
      [:refined, args]
    end
  end
end
using DynamicRefinement
p h.dynamic(4)
class UserTombstoneOptions < Options
  def removed
    :old
  end
  undef_method :removed
end
p UserTombstoneOptions.new.removed
class RaisingHash < Hash
  def method_missing(name, *args, **keywords, &block)
    super
  end
end
begin
  RaisingHash.new.absent(1)
rescue NoMethodError => error
  p [error.name, error.args, error.receiver.class]
end
