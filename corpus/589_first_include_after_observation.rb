mix = Module.new do
  def included_marker
    :included
  end
end
seen = []
Object.define_singleton_method(:inherited) do |child|
  # Warm both kinds of lookup before Class.new starts its include body.
  seen << [child.ancestors.size, child.method_defined?(:included_marker)]
end
owner = Class.new { include mix }
Object.singleton_class.send(:remove_method, :inherited)
p [seen.last[1], owner.ancestors.include?(mix), owner.method_defined?(:included_marker)]
p owner.new.included_marker

other = Class.new { include mix }
p [other.ancestors.include?(mix), other.new.included_marker]
mix.module_eval { def added_after_include; :later; end }
p [owner.new.added_after_include, other.new.added_after_include]
