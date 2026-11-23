# Proc's own #source_location and #ruby2_keywords are methods of Proc that
# reflection sees: `Proc.method_defined?(:source_location)` was false, and
# rspec-core took its Ruby 1.8.7 path on that answer (it then extends the
# block, shared_example_group.rb)
p Proc.method_defined?(:source_location)
p Proc.method_defined?(:ruby2_keywords)
p Proc.public_method_defined?(:source_location)
p Proc.instance_method(:source_location).owner
p Proc.instance_method(:ruby2_keywords).owner
pr = proc { |*a| a }
p pr.respond_to?(:source_location)
p pr.respond_to?(:ruby2_keywords)
p pr.source_location.is_a?(Array)
p pr.ruby2_keywords.equal?(pr)
p %i[call arity lambda? curry parameters source_location ruby2_keywords].map { Proc.method_defined?(_1) }
