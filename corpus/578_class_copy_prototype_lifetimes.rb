# A native-family copy and a subclass of that copy keep their allocation
# protocol after the intermediate class variables have left scope.
def copied_time_family
  base = Time.dup
  copy = base.clone
  child = Class.new(copy)
  [copy, child]
end
copy, child = copied_time_family
GC.start
raise unless copy.now.class.equal?(copy)
raise unless child.now.class.equal?(child)
raise unless copy.at(0).class.equal?(copy)
raise unless child.at(0).class.equal?(child)
raise unless copy.utc(2020).class.equal?(copy)
raise unless child.utc(2020).class.equal?(child)

# Repeated copies still use the permanent native allocation family after
# collections and after their intermediate source variables leave scope.
20.times { copy = copy.dup }
GC.start
raise unless copy.now.class.equal?(copy)
raise unless copy.utc(2020).class.equal?(copy)
raise unless copy.at(0).class.equal?(copy)
puts 'class copy prototypes preserve native allocation across collections'
