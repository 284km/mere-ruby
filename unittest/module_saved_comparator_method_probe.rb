# Existing native Method dispatch gap, separate from selected-super lookup.
# Ruby prints true/false; both the #141 parent and the candidate fail at call.
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
