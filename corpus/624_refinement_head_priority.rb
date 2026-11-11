class RefinementHeadTarget
  def value; :base; end
  def older_only; :base_older; end
end
module RefinementHeadOld
  refine RefinementHeadTarget do
    def value; :older; end
    def older_only; :older_only; end
  end
end
module RefinementHeadNew
  refine RefinementHeadTarget do
    def value; :newest; end
  end
end
module RefinementHeadScope
  using RefinementHeadOld
  using RefinementHeadNew
  def self.read(object)
    [object.value, object.older_only, object.method(:value).call,
     object.method(:older_only).unbind.bind_call(object)]
  end
end
object = RefinementHeadTarget.new
p RefinementHeadScope.read(object)
GC.start
p RefinementHeadScope.read(object)
module RefinementHeadUndefined
  refine RefinementHeadTarget do
    undef_method :value
  end
end
module RefinementHeadUndefinedScope
  using RefinementHeadOld
  using RefinementHeadUndefined
  def self.read(object)
    object.value
  rescue NoMethodError => error
    error.class
  end
end
p RefinementHeadUndefinedScope.read(object)
module RefinementHeadStringOld
  refine String do
    def label; :older_label; end
  end
end
module RefinementHeadStringNew
  refine String do
    alias_method :label, :upcase
  end
end
module RefinementHeadStringScope
  using RefinementHeadStringOld
  using RefinementHeadStringNew
  def self.read(object)
    [object.label, object.method(:label).call]
  end
end
p RefinementHeadStringScope.read('mixed')
module RefinementHeadPrepend
  def value; :prepended; end
end
RefinementHeadTarget.prepend(RefinementHeadPrepend)
GC.start
p RefinementHeadScope.read(object)
p [object.value, object.older_only]
