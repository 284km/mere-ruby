module Registry
  def self.subclasses
    @subclasses ||= []
  end
end
Registry.subclasses << :entry
p Registry.subclasses
p Registry.instance_variable_get(:@subclasses)
p Registry.method(:subclasses).owner.to_s
