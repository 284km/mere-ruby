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
