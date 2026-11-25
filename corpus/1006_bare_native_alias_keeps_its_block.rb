class ForwardedNativeUpdate1006 < Hash
  alias regular_update update
  def update(*others, &block)
    apply_update(others.first, block)
    self
  end
  alias merge! update
  def apply_update(other, block)
    regular_update(other, &block)
  end
end
hash = ForwardedNativeUpdate1006.new
hash['person'] = { first: 'David' }
p hash.merge!('person' => {}, 'id' => '1234') { |key, left, right| [key, left, right] }
hash['person'] = { first: 'David' }
p hash.update('person' => {}) { |key, left, right| left }
p hash.regular_update('person' => {}) { |key, left, right| left }
p hash.update('person' => {})
