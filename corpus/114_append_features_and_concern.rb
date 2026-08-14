# `include M` is not a primitive: Module#append_features is what actually adds
# the module to the base's ancestors, and a module may override it. That hook
# is the whole of ActiveSupport::Concern -- the ClassMethods extension and the
# `included do` block both happen inside it -- so it is written out here.
module Concernish
  def self.extended(base)
    base.instance_variable_set(:@_included_block, nil)
  end

  def append_features(base)
    $order << [:append_features, base.to_s]
    super
    base.extend(const_get(:ClassMethods)) if const_defined?(:ClassMethods)
    blk = instance_variable_get(:@_included_block)
    base.class_eval(&blk) if blk
  end

  def included(base = nil, &block)
    if base.nil?
      instance_variable_set(:@_included_block, block)
    else
      $order << [:included, base.to_s]
      super
    end
  end
end

$order = []
module Greet
  extend Concernish

  included do
    @from_included_block = :ran
  end

  module ClassMethods
    def greeting
      "class method"
    end
  end

  def greet
    "instance method"
  end
end

class Host
  include Greet
end

p Host.greeting
p Host.new.greet
p Host.instance_variable_get(:@from_included_block)
p Host.ancestors.include?(Greet)
p Host.new.is_a?(Greet)
p $order

# append_features can also REFUSE to include -- it is the decision, not a
# notification. (Concern does this for a module that is still collecting
# dependencies.)
module Refuses
  def self.append_features(base)
    false
  end

  def never
    :never
  end
end
class Host2
  include Refuses
end
p Host2.ancestors.include?(Refuses)
p Host2.new.respond_to?(:never)

# prepend_features is the same hook for the front of the chain
module Front
  def self.prepend_features(base)
    $front = base.to_s
    super
  end

  def v
    "front-" + super
  end
end
class Host3
  def v
    "host3"
  end
  prepend Front
end
p [Host3.new.v, $front, Host3.ancestors.first(2)]

# ...and a module with no hook of its own still includes the ordinary way
module Plain
  def plain
    :plain
  end
end
class Host4
  include Plain
end
p [Host4.new.plain, Host4.ancestors.include?(Plain)]
