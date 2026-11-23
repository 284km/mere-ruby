# Proc#extend mixes the module into the proc's singleton class, as for any
# object: it was a NoMethodError (rspec-core's 1.8.7 path extends a block)
mod = Module.new { def x = 1 }
pr = proc { 2 }
p pr.extend(mod).equal?(pr)
p [pr.x, pr.call, pr.singleton_class.include?(mod), pr.is_a?(mod)]
l = lambda { 3 }
l.extend(mod)
p [l.x, l.lambda?, l.()]
p proc { 4 }.respond_to?(:x)
