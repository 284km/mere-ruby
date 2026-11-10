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

# Empty class copies need no chain of prior copies to answer native-family
# queries. Weak keys expose accidentally retained intermediate identities.
def latest_copy_and_weak_keys
  weak = ObjectSpace::WeakMap.new
  klass = Class.new
  40.times do
    weak[klass] = true
    klass = klass.dup
  end
  [klass, weak]
end
latest, weak = latest_copy_and_weak_keys
5.times { GC.start }
raise unless latest.new.class.equal?(latest)
raise unless weak.size == 0
puts 'class copy prototypes preserve native allocation without retaining intermediates'
