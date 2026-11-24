# Interpreter metadata is private; only Ruby-visible Arrays/Hashes belong in
# count_objects and each_object. No CRuby-only temporary allocations are copied.
require 'objspace'
$counts = {}
def measure(label)
  ObjectSpace.count_objects($counts)
  arrays = $counts[:T_ARRAY]
  hashes = $counts[:T_HASH]
  yield
  ObjectSpace.count_objects($counts)
  p [label, $counts[:T_ARRAY] - arrays, $counts[:T_HASH] - hashes]
end
def arrays
  n = 0
  ObjectSpace.each_object(Array) { n += 1 }
  n
end
def self.cold_parameter(x)
  x.to_i
  nil
end
def self.cold_keyword(a: nil) = nil
def self.cold_rest(*args)
  args.length
  nil
end
def none = nil
def keyword_rest(**keywords) = keywords
empty = {}
GC.start
GC.disable
measure(:cold_parameter) { cold_parameter(1) }
measure(:cold_keyword) { cold_keyword(**empty) }
measure(:cold_rest) { cold_rest(1) }
measure(:empty_keywords) { none(**empty) }
measure(:nil_keywords) { none(**nil) }
measure(:empty_keyword_rest) { keyword_rest(**empty) }
measure(:public_count_result) { ObjectSpace.count_objects }

def self.first_array_observer(x)
  x.to_i
  nil
end
arrays
before = arrays
first_array_observer(1)
p [:private_metadata, arrays - before]

$effects = []
converter = Object.new
def converter.to_hash
  $effects << :to_hash
  {}
end
measure(:empty_conversion) { none(**converter) }
p $effects
original = {a: 1}
copy = keyword_rest(**original)
copy[:a] = 2
p [:keyword_copy, original[:a], copy[:a], original.equal?(copy)]

# Cache flags must follow the cache's existing GC lifetime and keep super's
# parameter binding intact across collection, aliasing and redefinition.
class AllocationParent
  def f(x, *rest, **keywords) = [x, rest, keywords]
end
class AllocationChild < AllocationParent
  def f(x, *rest, **keywords)
    GC.start
    super
  end
  alias old_f f
end
p AllocationChild.new.old_f(1, 2, a: 3)
class AllocationChild
  def f(x, *rest, **keywords)
    x += 1
    GC.start
    super
  end
end
p AllocationChild.new.f(1, 2, a: 3)
GC.start
ObjectSpace.count_objects($counts)
p [:nonnegative, $counts[:T_ARRAY] >= 0, $counts[:T_HASH] >= 0]
