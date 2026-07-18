class Animal
  def initialize(name)
    @name = name
  end
  def name
    @name
  end
  def speak
    @name + " makes a sound"
  end
  def describe
    @name + ": " + speak
  end
end
class Dog < Animal
  def speak
    @name + " barks"
  end
end
class Cat < Animal
  def speak
    @name + " meows"
  end
end
a = Animal.new("thing")
d = Dog.new("Rex")
c = Cat.new("Felix")
puts a.speak
puts d.speak
puts c.speak
puts d.describe
puts c.describe
puts d.name
