class RecordOwner1141
  def entry(a)
    [__method__, __callee__, a]
  end
end
object = RecordOwner1141.new
old = object.method(:entry)
3.times { p object.entry(1) }

class UnrelatedOwner1141
end
5.times do |index|
  UnrelatedOwner1141.define_method(:changing) { index }
  p object.entry(index)
end

class RecordOwner1141
  def entry(a, b = 2)
    [__method__, __callee__, a, b]
  end
  alias saved entry
end
p object.entry(3), object.saved(4), old.call(5)
p object.method(:entry).parameters, old.parameters
aliased = object.method(:saved)

RecordOwner1141.define_method(:entry) do |value:, **rest|
  [__method__, __callee__, value, rest]
end
p object.entry(value: 6, extra: 7), aliased.call(8)
p object.method(:entry).parameters, aliased.parameters

def record_top1141(value)
  [__method__, __callee__, value]
end
old_top = method(:record_top1141)
p record_top1141(1)
def record_top1141
  [__method__, __callee__, :new]
end
p record_top1141, old_top.call(2)
GC.start
p old.call(9), aliased.call(10), old_top.call(11)

module LexicalRecord1141
  VALUE = :outer
  class Owner
    def read = VALUE
  end
end
lexical = LexicalRecord1141::Owner.new
p lexical.read
module OtherLexicalRecord1141
  VALUE = :replacement
  LexicalRecord1141::Owner.class_eval do
    define_method(:read) { VALUE }
  end
end
p lexical.read

# A child's positive and negative lookups must see later parent changes,
# including dependencies learned before any local mutation is adopted.
class RecordParent1141
  def value(x) = [:old, x]
end
class RecordChild1141 < RecordParent1141
end
child = RecordChild1141.new
3.times { p [child.value(1), child.respond_to?(:missing)] }
class RecordParent1141
  def value(x) = [:new, x]
  def missing(x) = [:added, x]
end
p [child.value(2), child.missing(3)]
RecordParent1141.class_eval { remove_method :value, :missing }
p [child.respond_to?(:value), child.respond_to?(:missing)]

class RecordReader1141
  attr_reader :value
  def initialize = @value = :reader
end
reader = RecordReader1141.new
3.times { p reader.value }
class RecordReader1141
  def value = :replacement
end
p reader.value
RecordReader1141.class_eval { remove_method :value }
p reader.respond_to?(:value)

class RecordSwitchA1141
  def value(x) = [:a, x]
end
class RecordSwitchB1141
  def value(x) = [:b, x]
end
a, b = RecordSwitchA1141.new, RecordSwitchB1141.new
3.times do |i|
  p [a.value(i), b.value(i)]
  RecordSwitchA1141.define_method(:value) { |x| [:changed_a, x] }
  RecordSwitchB1141.define_method(:value) { |x| [:changed_b, x] }
end
p [a.value(9), b.value(9)]

module RecordSuper1141
  def value(x) = [:prepended, super]
end
RecordSwitchA1141.prepend(RecordSuper1141)
p a.value(10)
RecordSwitchA1141.define_method(:value) { |x| [:after_prepend, x] }
p a.value(11)

class RecordHook1141
  def self.method_added(name)
    raise 'hook raised' if name == :value
  end
end
begin
  RecordHook1141.class_eval { def value(x) = x }
rescue => e
  p e.message
end
p RecordHook1141.new.value(12)
GC.start
p [a.value(13), b.value(14), child.respond_to?(:missing)]

# A captured top-level definition survives removal, undef and copy/bind.
def removed_top1141(value) = [:removed, value]
removed = method(:removed_top1141)
copied = removed.dup
unbound = removed.unbind
Object.send(:remove_method, :removed_top1141)
p removed.call(15), copied.call(16), unbound.bind(self).call(17)

def undefined_top1141(value) = [:undefined, value]
undefined = method(:undefined_top1141)
Object.send(:undef_method, :undefined_top1141)
p undefined.call(18)
GC.start
p removed.call(19), undefined.call(20)

p old_top[21], old_top.(22), old_top === 23

# Removing unused boundaries must preserve the original era of a surviving
# copy, including an UnboundMethod with its own singleton class.
def successive_top1141 = :first
first = method(:successive_top1141)
def successive_top1141 = :middle
middle = method(:successive_top1141)
middle_copy = middle.dup.unbind
def middle_copy.tag = :tag
def successive_top1141 = :last
first = nil
middle = nil
6.times { GC.start }
p [middle_copy.bind(self).call, middle_copy.tag, successive_top1141]

# A discarded Method must release its saved define_method closure. The
# current definition is installed in another frame so it cannot capture the
# old argument. Conservative collection may keep some targets, but not all.
$released_snapshot1141 = []
def snapshot_finalizer1141
  proc { |id| $released_snapshot1141 << id }
end
def publish_discarded_snapshot1141(value)
  Object.send(:define_method, :discarded_top1141) { value }
  method(:discarded_top1141)
end
def reset_discarded_snapshot1141
  Object.class_eval { def discarded_top1141 = :current }
end
Fiber.new do
  20.times do
    value = Object.new
    ObjectSpace.define_finalizer(value, snapshot_finalizer1141)
    publish_discarded_snapshot1141(value)
    reset_discarded_snapshot1141
  end
  nil
end.resume
12.times { GC.start }
raise 'discarded Method retained every old closure' if $released_snapshot1141.empty?
p [:discarded_snapshots_released, discarded_top1141]
