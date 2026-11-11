owner = Class.new
name = "caf\u00e9"
owner.define_method(name) { :retained }
receiver = owner.new
bound = receiver.method(name)
held = bound.unbind
name.replace('changed')
GC.start
p [bound.name, held.name, bound.owner.equal?(owner), held.owner.equal?(owner)]
p [bound == held.bind(receiver), bound.hash == held.bind(receiver).hash]
owner.class_eval { alias_method :alternate, :café }
p [receiver.method(:alternate).original_name, receiver.method(:alternate).unbind == held]
owner.send(:remove_method, :café)
bound = nil
GC.start
p [held.bind_call(receiver), receiver.method(:alternate).call]

class MethodMetadataParent
  def self.value; :singleton_parent; end
end
class MethodMetadataChild < MethodMetadataParent
end
singleton = MethodMetadataParent.method(:value).unbind
GC.start
p [singleton.owner.equal?(MethodMetadataParent.singleton_class),
   singleton.bind_call(MethodMetadataChild)]
