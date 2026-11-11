[Class, Module].each do |factory|
  outer = :captured
  created = factory.new do |identity|
    raise "wrong self" unless self.equal?(identity)
    define_method(:captured) { outer }
    private
    def hidden; :private_value; end
  end
  receiver = factory == Class ? created.new : Object.new.extend(created)
  p [receiver.captured, created.private_instance_methods(false).include?(:hidden)]
  p factory.new { break :constructor_break }
  frames = []
  factory.new { GC.start; frames << caller(0).any? { |line| line.include?("new") } }
  p frames
  begin
    factory.new { raise "body error" }
  rescue RuntimeError => e
    p e.message
  end
end
$inherited_constructor_probe = 0
def Object.inherited(child)
  $inherited_constructor_probe += 1
end
Class.new {}
p $inherited_constructor_probe
Object.singleton_class.send(:remove_method, :inherited)
class << Class
  def new(&block)
    [:class_override, !block.nil?]
  end
end
p Class.new { :body }
Class.singleton_class.send(:remove_method, :new)
p Class.new {}.superclass
