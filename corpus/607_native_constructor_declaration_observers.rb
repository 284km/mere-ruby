line = __LINE__ + 2
plain = Class.new do
  def answer; :plain; end
end
p [plain.new.answer, plain.instance_method(:answer).source_location == [__FILE__, line]]

target = Class.new { def answer; :base; end }
line = __LINE__ + 3
refinery = Module.new do
  refine target do
    def answer; :refined; end
  end
end
p refinery.refinements.first.instance_method(:answer).source_location == [__FILE__, line]
line = __LINE__ + 3
scope = Class.new do
  using refinery
  def read(object); object.answer; end
end
p [scope.new.read(target.new), scope.instance_method(:read).source_location == [__FILE__, line]]

# An inherited callback can see the constructor frame; it must prevent the
# frameless declaration path even after default constructor caches warm.
$native_declaration_frames = []
class << Object
  def inherited(child)
    $native_declaration_frames << caller_locations.any? { |frame| frame.base_label == 'new' }
  end
end
observed = Class.new { def answer; :observed; end }
class << Object
  remove_method :inherited
end
p [$native_declaration_frames, observed.new.answer]
$native_declaration_frames = nil

# A refined factory still replaces a new call whose literal block is pure.
module NativeDeclarationRefinedFactories
  refine Class.singleton_class do
    def new; :refined_class_factory; end
  end
  refine Module.singleton_class do
    def new; :refined_module_factory; end
  end
end
using NativeDeclarationRefinedFactories
p Class.new { def answer; :unused; end }
p Module.new { def answer; :unused; end }
