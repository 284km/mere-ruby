[0, 1, 16, 17, 64].each do |size|
  source = Array.new(size) { |index| ["k#{index}", [index]] }.to_h
  copies = [source.dup, source.clone, {}.replace(source)]
  source['k0'] = [:source]
  source['tail'] = :extra
  source.delete('k1')
  p [:source_write, size, copies.map { |copy| [copy.size, copy['k0'], copy['k1'], copy.key?('tail')] }]
  copies[0]['k0'] = [:copy]
  copies[0]['new'] = :new
  copies[0].delete('k2')
  copies[1].replace('replacement' => true)
  copies[2].clear
  GC.start
  p [:copy_write, size, source['k0'], source.key?('new'), copies.map(&:size)]
end

source = (0...64).to_h { |index| [index, index] }
source[0] = :before_copy
copy = source.dup
source[0] = :after_copy
copy[1] = :copy_only
copy[65] = :new
source[100] = :pending
second = source.dup
source.delete(2)
GC.start
p [:pending_and_stale, copy[0], source[1], copy[65], source.key?(65), second[100], second[2], source.key?(2)]

shared_value = []
source = (0...64).to_h { |index| [index, index] }
source[:shared] = shared_value
copy = source.dup
shared_value << :visible
p [:shallow_values, copy[:shared], copy[:shared].equal?(source[:shared])]

source = Hash.new { |hash, key| hash[key] = [:default, key] }
64.times { |index| source[index] = index }
source.instance_variable_set(:@tag, :source_tag)
copy = source.dup
copy[:missing] << :copy_only
p [:default_proc, copy.default_proc.equal?(source.default_proc), source.key?(:missing), copy[:missing], copy.instance_variable_get(:@tag)]

first_key, second_key = +'same', +'same'
source = {}.compare_by_identity
source[first_key] = [:first]
source[second_key] = [:second]
copy = source.dup
source[first_key] = :source_only
copy[second_key] = :copy_only
p [:identity_copy, source.size, copy.size, copy[first_key], source[second_key], copy.compare_by_identity?]
copy.replace(copy)
p [:identity_self_replace, copy.compare_by_identity?, copy[first_key], copy[second_key]]

mutable_key = [:before]
source = {mutable_key => :stored}
copy = source.dup
mutable_key << :after
p [:mutable_key_after_copy, source.keys, copy.keys, source.keys.first.equal?(copy.keys.first)]
source.rehash
copy.rehash
copy[mutable_key] = :copy_only
p [:rehash_independence, source[mutable_key], copy[mutable_key]]

source = (0...64).to_h { |index| [index, [index]] }
copy = source.dup
second = copy.dup
source = nil
copy = nil
8.times do
  50.times { Object.new }
  GC.start
end
p [:last_owner, second.size, second[0], second[63]]
third = {}.replace(second)
second.clear
GC.start
p [:replace_last_owner, third.size, third[0], third[63]]

source = (0...64).to_h { |index| [index, index] }
source.freeze
copy = source.dup
clone = source.clone
unfrozen_clone = source.clone(freeze: false)
copy[0] = :copy
unfrozen_clone[1] = :clone
begin
  clone[0] = :forbidden
rescue => error
  p [:frozen_copy, source[0], copy[0], clone[0], clone.frozen?, unfrozen_clone[1], error.class]
end

class HashCopySubclass1137 < Hash
  def initialize_copy(other)
    super
    @copied = true
  end
  def copied? = @copied
end
source = HashCopySubclass1137.new
64.times { |index| source[index] = index }
copy = source.dup
source[0] = :source
copy[1] = :copy
p [:subclass, copy.class, copy.copied?, copy[0], source[1]]

source = (0...64).to_h { |index| [index, index] }
copy = source.dup
seen = []
copy.each do |key, value|
  source[key] = :changed
  copy[key] = value + 1
  seen << [key, value] if key < 2
end
p [:iteration, seen, copy[0], copy[63], source[0]]
