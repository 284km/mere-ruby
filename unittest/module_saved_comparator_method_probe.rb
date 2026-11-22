# A captured native Module comparator keeps its body after a prepend.
# Both runtimes print true/false; the original dispatch failed at call.
saved = Module.instance_method(:===)
module SavedComparatorForwarder
  def ===(value)
    super
  end
end
Module.prepend(SavedComparatorForwarder)
class SavedComparatorTarget; end
p saved.bind(SavedComparatorTarget).call(SavedComparatorTarget.new)
p saved.bind(SavedComparatorTarget).call(Object.new)
