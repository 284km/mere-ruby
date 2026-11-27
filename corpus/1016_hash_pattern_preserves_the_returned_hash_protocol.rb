class PatternHash1016 < Hash
  attr_reader :events
  def initialize(events = [])
    @events = events
  end
  def deconstruct_keys(keys)
    @events << [:deconstruct, keys]
    self
  end
  def key?(key)
    @events << [:key, key]
    super(key.to_s)
  end
  def [](key)
    @events << [:read, key]
    super(key.to_s)
  end
  def delete(key)
    @events << [:delete, key]
    super(key.to_s)
  end
  def dup
    @events << :dup
    copy = self.class.new(@events)
    each_pair { |key, value| copy[key] = value }
    copy
  end
end
hash = PatternHash1016.new
hash['foo'] = 'fighters'
hash['bar'] = 'bar'
p(case hash; in {foo: /fighter/}; true; else; false; end)
p hash.events
hash.events.clear
p(case hash; in {foo: /mismatch/, bar: /bar/}; true; else; false; end)
p hash.events
hash.events.clear
hash => {foo: value, **rest}
p [value, rest.class.name, rest.keys, hash.keys]
p hash.events
class PatternWrapper1016
  def initialize(hash)
    @hash = hash
  end
  def deconstruct_keys(keys)
    @hash
  end
end
p(case PatternWrapper1016.new(hash); in {foo: 'fighters'}; true; else; false; end)
begin
  PatternWrapper1016.new(hash) => {missing:}
rescue NoMatchingPatternKeyError => error
  p [error.key, error.matchee.equal?(hash)]
end
class ReplacedPatternHash1016 < Hash
  def deconstruct_keys(keys)
    {changed: keys}
  end
end
p(case ReplacedPatternHash1016.new; in {changed: [:changed]}; true; else; false; end)
class HiddenPatternHash1016 < PatternHash1016
  def respond_to?(name, *)
    return false if name == :deconstruct_keys
    super
  end
end
p(case HiddenPatternHash1016.new; in {}; true; else; false; end)
class BadPatternHash1016 < Hash
  def deconstruct_keys(keys) = false
end
begin
  BadPatternHash1016.new => {}
rescue TypeError => error
  p error.message
end
class EmptyPatternHash1016 < Hash
  def empty? = true
end
nonempty = EmptyPatternHash1016.new
nonempty[:extra] = 1
p(case nonempty; in {}; true; else; false; end)
only_foo = PatternHash1016.new
only_foo['foo'] = 'fighters'
p(case only_foo; in {foo: 'fighters', **nil}; true; else; false; end)
p(case hash; in {foo: 'fighters', **nil}; true; else; false; end)
class PrivateKeyPatternHash1016 < PatternHash1016
  private :key?
end
begin
  PrivateKeyPatternHash1016.new => {foo:}
rescue NoMethodError => error
  p [error.class, error.name]
end
