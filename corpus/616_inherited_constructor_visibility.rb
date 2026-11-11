klass = Class.new
3.times { klass.new }
Object.singleton_class.send(:private, :new)
begin
  klass.new
  raise 'inherited private constructor was bypassed'
rescue NoMethodError => error
  p [error.name, error.receiver.equal?(klass)]
end
p klass.send(:new).class.equal?(klass)
Object.singleton_class.send(:public, :new)
GC.start
p klass.new.class.equal?(klass)

klass.singleton_class.send(:private, :new)
begin
  klass.new
  raise 'own private constructor was bypassed'
rescue NoMethodError => error
  p [error.name, error.receiver.equal?(klass)]
end
p klass.send(:new).class.equal?(klass)
