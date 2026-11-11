# Native Time prototypes survive copies and collection without retaining a
# chain of source copies. Plain module copies still carry their Ruby methods.
def native_time_copy
  source = Time.dup
  source.dup
end
copy = native_time_copy
3.times { GC.start }
p [copy.at(0).class.equal?(copy), copy.now.class.equal?(copy), copy.new(2001, 2, 3).year]
copy = copy.clone
3.times { GC.start }
p [copy.at(0).class.equal?(copy), copy.now.class.equal?(copy), copy.new(2004, 5, 6).year]

subclass = Class.new(Time)
subcopy = subclass.dup
subclass = nil
3.times { GC.start }
p [subcopy.at(0).class.equal?(subcopy), subcopy.now.class.equal?(subcopy)]

original = Module.new do
  def value
    :copied
  end
end
modcopy = original.clone
original = nil
3.times { GC.start }
object = Object.new
object.extend(modcopy)
p [object.value, modcopy.instance_methods(false).sort]
