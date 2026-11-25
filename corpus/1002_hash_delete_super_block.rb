class ConvertedDelete < Hash
  def delete(key, &block)
    super(key.to_s, &block)
  end
end
hash = ConvertedDelete.new
hash["present"] = 7
p hash.delete(:present) { raise "existing key must not yield" }
p hash.delete(:missing) { |key| [key, :fallback] }
p hash.delete(:missing)
hash["false"] = false
p hash.delete(:false) { raise "false is a present value" }
hash["nil"] = nil
p hash.delete(:nil) { raise "nil is a present value" }
p hash.delete(:missing) { break :escaped }
hash.freeze
begin
  hash.delete(:missing) { raise "frozen receiver must not yield" }
rescue FrozenError => error
  p [error.class, error.receiver.equal?(hash)]
end
