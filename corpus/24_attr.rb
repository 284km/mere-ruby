class Box
  attr_accessor :value
  attr_reader :label
  def initialize(label, value)
    @label = label
    @value = value
  end
end
b = Box.new("width", 100)
puts b.label
puts b.value
b.value = 250
puts b.value
b.value = b.value + 1
puts b.value
puts b.label
