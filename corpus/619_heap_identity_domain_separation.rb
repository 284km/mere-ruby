$VERBOSE = nil
identity = BasicObject.instance_method(:__id__)
samples = [Object.new, String.new('live'), [], {}, proc {}, binding,
           Class.new, Module.new, /identity/, :identity_domain,
           method(:puts), String.instance_method(:upcase), STDOUT]
ids = samples.map { |object| object.__id__ }
raise 'mixed live identities collide' unless ids.uniq.length == ids.length
raise 'identity dispatch differs' unless samples.all? do |object|
  identity.bind_call(object) == object.__id__
end
# Exercise the existing reverse-lookup domains. Container/Proc/Binding/Regexp
# enumeration is separate from the identity-domain allocation being tested.
raise 'identity reverse lookup changed' unless samples.values_at(0, 1, 6, 7, 9).all? do |object|
  ObjectSpace._id2ref(object.__id__).equal?(object)
end
puts 'mixed heap identities and reverse lookup agree'

# Keep every value live. Disabling automatic GC makes the large identity
# boundary deterministic and avoids making a GC-stress run quadratic.
disabled = GC.disable
begin
  strings = Array.new(130_000) { String.new }
  arrays = Array.new(2_000) { [] }
  hashes = Array.new(2_000) { {} }
  all_ids = []
  # Retain the full allocation boundary, then sample strings across it.
  # The smaller sort keeps the same case practical with Hash indexing off.
  sampled_strings = 0
  strings.each_with_index do |object, index|
    if index % 64 == 0
      all_ids << object.__id__
      sampled_strings += 1
    end
  end
  [arrays, hashes].each do |objects|
    objects.each do |object|
      all_ids << object.__id__
    end
  end
  raise 'heap identity count changed' unless sampled_strings == 2032 && all_ids.length == sampled_strings + arrays.length + hashes.length
  previous = nil
  all_ids.sort.each do |key|
    raise 'live heap identities collide across types' if previous == key
    previous = key
  end
ensure
  GC.enable unless disabled
end
GC.start
raise 'a live identity changed after collection' unless samples.map { |object| object.__id__ } == ids
raise 'String identity reverse lookup changed' unless ObjectSpace._id2ref(strings.last.__id__).equal?(strings.last)
puts 'large live heap identity domains remain separate after collection'
