class CopySentinel
  def dup = :nested_override
end

module CopyHooks
  private
  def initialize_copy(original)
    super
    @nested_copy = CopySentinel.new.dup
  end
end

class CopyPlain
  include CopyHooks
  def dup = super
  def clone(...) = super
end
class CopyString < String
  include CopyHooks
  def dup = super
  def clone(...) = super
end
class CopyArray < Array
  include CopyHooks
  def dup = super
  def clone(...) = super
end

def check_copies(original)
  original.instance_variable_set(:@data, [1, 2])
  def original.marker = :original_singleton
  [:dup, :clone].each do |method|
    copy = original.public_send(method)
    p [method, copy.class, copy.equal?(original),
       copy.instance_variable_get(:@data),
       copy.instance_variable_get(:@data).equal?(original.instance_variable_get(:@data)),
       copy.instance_variable_get(:@nested_copy), copy.respond_to?(:marker)]
    if method == :clone
      p copy.marker
      def copy.marker = :copied_singleton
      p [original.marker, copy.marker]
    end
    if copy.is_a?(String)
      copy << 'b'
      p [original, copy]
    elsif copy.is_a?(Array)
      copy << :b
      p [original, copy]
    end
  end
  original.freeze
  p [original.dup.frozen?, original.clone.frozen?,
     original.clone(freeze: false).frozen?]
end

[CopyPlain.new, CopyString.new('a'), CopyArray.new([:a])].each do |object|
  check_copies(object)
end

# A second Ruby super target still runs before the native copy.
module CopyBeforePlain
  def dup = super
end
CopyPlain.prepend(CopyBeforePlain)
object = CopyPlain.new
p [object.dup.class, object.dup.equal?(object)]
