# Run with MERE_RUBY_GC_TIGHT=1 and a fixed --seed=1.
count = Integer(ARGV.fetch(0))
kind = ARGV.fetch(1, 'capture')
class DefineMethodBenchBase
  def value = block_given? ? yield : 1
end

def install_captured(klass)
  klass.define_method(:value) { yield }
  klass.define_method(:other) { 1 }
end

def install_super(klass)
  klass.define_method(:value) { super() }
  klass.define_method(:other) { 1 }
end

def install_plain(klass)
  klass.define_method(:value) { 1 }
  klass.define_method(:other) { 1 }
end

def ordinary_yield
  yield
end

if kind == 'yield_loop'
  sum = 0
  count.times { sum += ordinary_yield { 1 } }
  p [kind, sum]
elsif kind == 'super_loop'
  klass = Class.new(DefineMethodBenchBase)
  install_super(klass) { 1 }
  object = klass.new
  sum = 0
  count.times { sum += object.value }
  p [kind, sum]
else
  classes = []
  count.times do
    klass = Class.new(DefineMethodBenchBase)
    case kind
    when 'capture' then install_captured(klass) { 1 }
    when 'super' then install_super(klass) { 1 }
    when 'plain' then install_plain(klass) { 1 }
    else raise ArgumentError, 'unknown benchmark case'
    end
    classes << klass
  end
  GC.start
  p [kind, classes.size]
end
