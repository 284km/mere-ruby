# The reflection lists of the core classes name the methods each class
# defines itself (note 433): String.instance_methods(false) and the lists
# inherited from it, and a value answers respond_to? for what they name.

%w[String Array Hash Integer Float Symbol Range NilClass TrueClass Proc Regexp].each do |cn|
  c = Object.const_get(cn)
  puts "#{cn}: own #{c.public_instance_methods(false).size} all #{c.instance_methods.size}"
end

# a sample of names, both ways
p String.instance_methods(false).include?(:upcase)
p Array.public_instance_methods.include?(:each_slice)
p Hash.instance_methods(false).include?(:to_a)
p Integer.instance_methods.include?(:between?)

# respond_to? on values agrees with the lists
p "s".respond_to?(:instance_eval)
p [].respond_to?(:sum)
p 1.respond_to?(:clamp)

# Complex undefines Numeric's ordering and rounding
c = Complex(1, 1)
p [:%, :div, :divmod, :floor, :ceil, :<, :between?].map { |m| c.respond_to?(m) }
p Complex.instance_methods.include?(:floor)
p Complex.instance_methods.include?(:abs)

# a class that undefines one no longer answers it
class Fooo < Array
  undef_method :first
end
p Fooo.new.respond_to?(:first)
p Fooo.instance_methods.include?(:first)
p Fooo.instance_methods.include?(:last)

# a private builtin stays out of the public list
p String.public_instance_methods.include?(:initialize)
p Kernel.private_instance_methods.include?(:puts)
