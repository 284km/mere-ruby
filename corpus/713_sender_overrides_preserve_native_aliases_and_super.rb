$VERBOSE = nil

class RubySenders
  def send(*args, **keywords, &block)
    [:send_override, args, keywords, block && block.call]
  end
  def __send__(*args, **keywords, &block)
    [:double_override, args, keywords, block && block.call]
  end
  def public_send(*args, **keywords, &block)
    [:public_override, args, keywords, block && block.call]
  end
end
object = RubySenders.new
p object.send
p object.__send__(:item, n: 2) { :block }
p object.public_send
p object.public_send(:item) { :block }

class NativeSenderAliases
  alias saved_send send
  alias saved_double __send__
  alias saved_public public_send
  def send(*) = :send_override
  def __send__(*) = :double_override
  def public_send(*) = :public_override
  def visible(value = :default, **keywords, &block)
    [value, keywords, block && block.call(:yielded)]
  end
  private
  def secret(value = :secret, &block)
    [value, block && block.call(:private_yield)]
  end
end
aliases = NativeSenderAliases.new
p aliases.saved_send(:secret, 4)
p aliases.saved_double(:secret, 5) { |value| [:block, value] }
p aliases.saved_public(:visible, 7, k: 8) { |value| [:block, value] }
begin
  aliases.saved_public(:secret)
rescue NoMethodError => error
  p [error.class, error.name, error.receiver.equal?(aliases)]
end
begin
  aliases.saved_public(:secret) { :must_not_yield }
rescue NoMethodError => error
  p [error.class, error.name, error.receiver.equal?(aliases)]
end

class SenderSuper
  def send(*args, **keywords, &block)
    [:outer_send, super]
  end
  def __send__(*args, **keywords, &block)
    [:outer_double, super]
  end
  def public_send(*args, **keywords, &block)
    [:outer_public, super]
  end
  def visible(value, **keywords)
    [value, keywords, block_given? && yield(:yielded)]
  end
  private
  def secret(value)
    [value, block_given? && yield(:private_yield)]
  end
end
forwarder = SenderSuper.new
p forwarder.send(:secret, 1) { |value| value }
p forwarder.__send__(:secret, 2)
p forwarder.public_send(:visible, 3, key: 4) { |value| value }
begin
  forwarder.public_send(:secret, 1)
rescue NoMethodError => error
  p [error.class, error.name, error.receiver.equal?(forwarder)]
end

class RetainedNativeSender
  def target(value)
    block_given? ? [value, yield] : value
  end
end
retained = RetainedNativeSender.new
original = retained.method(:public_send)
class RetainedNativeSender
  def public_send(*) = :overridden
end
p retained.public_send
p original.call(:target, 12)
name = Object.new
name.define_singleton_method(:to_str) do
  p retained.public_send
  'target'
end
p original.call(name, 13)
p original.call(:target, 14) { :block }
p original.call(name, 15) { :coerced_block }
begin
  original.call
rescue ArgumentError => error
  p [error.class, error.message]
end
p retained.public_send

class BareSender < BasicObject
  def public_send(*args)
    super
  end
end
begin
  BareSender.new.public_send(:object_id)
rescue NoMethodError => error
  p [error.class, error.name]
end

class ClassSenderAliases
  class << self
    alias saved_public public_send
    def public_send(*) = :class_override
    def target(number)
      [number, block_given? && yield]
    end
  end
end
p ClassSenderAliases.public_send
p ClassSenderAliases.saved_public(:target, 16) { :class_block }

text = +'content'
class << text
  alias saved_public public_send
  def public_send(*) = :string_override
end
p text.public_send
p text.saved_public(:length) { :unused }

module SenderRefinement
  refine NativeSenderAliases do
    def visible(number, **keywords)
      [:refined, number, keywords, block_given? && yield]
    end
  end
end
module SenderRefinementScope
  using SenderRefinement
  def self.run(object)
    object.saved_public(:visible, 17, key: 18) { :refined_block }
  end
end
p SenderRefinementScope.run(aliases)

module LaterSender
  def public_send(*) = :later_fallback
end
BasicObject.include(LaterSender)
p forwarder.public_send(:visible, 19) { :native_before_later }
