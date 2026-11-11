def consumed_return
  [1].each { return :consumed }
end
p consumed_return

mod = nil
klass = nil
3.times do
  mod = Module.new
  klass = Class.new { include mod }
end
p [klass.ancestors.include?(mod), klass.new.is_a?(mod)]

def ensure_metadata
  return :outer_return
ensure
  3.times do
    mod = Module.new
    Class.new { include mod }
  end
end
p ensure_metadata

$consumed_target_class = Class.new { def value; :value; end }
$consumed_refinery = Module.new do
  refine $consumed_target_class do
    def value; :refined; end
  end
end
factory = Class.new do
  using $consumed_refinery
  def initialize
    object = $consumed_target_class.new
    object.method(:value).unbind
  end
end
p factory.new.class == factory

p catch(:finished) { Class.new { throw :finished, :thrown } }
p consumed_return

def ensure_reflection(object)
  return :kept_return
ensure
  local = object
  local.method(:value).unbind
end
p ensure_reflection($consumed_target_class.new)

def block_return
  Class.new { return :class_return }
  :unreachable
end
p block_return
p Class.new.class

p catch(:ensure_result) {
  begin
    throw :ensure_result, :original
  ensure
    Class.new { def value; :after_throw; end }
  end
}
