# A bare missing name may be a local; parentheses or self make it a method
# call. The class, message, name and receiver survive a method_missing super.
module BareNamesModule
  def self.bare = nope_xyz
  def self.primitive_name = chr
  def self.explicit = self.nope_xyz
  def self.parenthesized = nope_xyz()
  def self.with_argument = nope_xyz(1)
end

class BareNamesClass
  def self.bare = nope_xyz
  def self.primitive_name = chr
  def self.explicit = self.nope_xyz
  def self.parenthesized = nope_xyz()
  def self.with_argument = nope_xyz(1)
  def bare = nope_xyz
  def explicit = self.nope_xyz
  def parenthesized = nope_xyz()
  def with_argument = nope_xyz(1)
end

def report_missing(label, receiver, method)
  begin
    receiver.public_send(method)
  rescue NameError => error
    p [label, method, error.class, error.message, error.name,
       error.receiver.equal?(receiver)]
  end
end

receivers = [BareNamesModule, BareNamesClass, BareNamesClass.new]
receivers.each_with_index do |receiver, index|
  methods = [:bare, :explicit, :parenthesized, :with_argument]
  methods << :primitive_name if index < 2
  methods.each do |method|
    report_missing(index, receiver, method)
  end
end

module BareNamesModule
  def self.method_missing(name, *args, &block) = super
end
class BareNamesClass
  def self.method_missing(name, *args, &block) = super
  def method_missing(name, *args, &block) = super
end
receivers.each_with_index do |receiver, index|
  methods = [:bare, :explicit, :parenthesized, :with_argument]
  methods << :primitive_name if index < 2
  methods.each do |method|
    report_missing(index + 3, receiver, method)
  end
end

# A missing call must not leave its context on an unrelated explicit call.
report_missing(:after_rescue, BareNamesModule, :explicit)
module BareNamesHandled
  def self.bare = nope_xyz
  def self.method_missing(name, *args) = [name, args]
end
p BareNamesHandled.bare

# The latest missing call replaces the reason even when its native default
# raises and is rescued. Successful calls and an explicit Ruby raise do not.
class NestedPrivateReceiver
  private
  def inner_missing = nil
  protected
  def protected_missing = nil
end
module NestedNativeMissing
  def bare = missing_name
  def primitive_name = chr
  def method_missing(name, *args)
    begin
      case @nested_probe
      when :object
        Object.new.inner_missing
      when :object_block
        Object.new.inner_missing { :unused }
      when :primitive
        ''.inner_missing
      when :class
        Object.inner_missing
      when :main
        TOPLEVEL_BINDING.receiver.inner_missing
      when :private
        NestedPrivateReceiver.new.inner_missing
      when :protected
        NestedPrivateReceiver.new.protected_missing
      when :successful
        Object.new.to_s
      when :ruby_raise
        raise NoMethodError, 'explicit Ruby raise'
      end
    rescue NoMethodError
    end
    super
  end
end
module NestedBareModule
  extend NestedNativeMissing
end
class NestedBareClass
  extend NestedNativeMissing
end
[NestedBareModule, NestedBareClass].each_with_index do |receiver, index|
  [:object, :object_block, :primitive, :class, :main, :private, :protected,
   :successful, :ruby_raise].each do |kind|
    receiver.instance_variable_set(:@nested_probe, kind)
    [:bare, :primitive_name].each do |method|
      report_missing([index, kind], receiver, method)
    end
  end
end
