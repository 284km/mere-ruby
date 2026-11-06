require 'openssl'
def show_digest_new(original)
  original.update('old')
  original.instance_variable_set(:@tag, :preserved)
  copy = original.new
  p [original.class.name, copy.class.name, copy.name,
     copy.instance_variable_get(:@tag), copy.equal?(original), copy.frozen?]
  p [copy.hexdigest, original.hexdigest]
  copy.update('abc')
  p [copy.hexdigest, original.hexdigest]
  original.update('more')
  p [copy.hexdigest, original.hexdigest]
end
show_digest_new(OpenSSL::Digest.new('SHA256'))
show_digest_new(OpenSSL::Digest::SHA1.new)
show_digest_new(OpenSSL::Digest::MD5.new)
show_digest_new(OpenSSL::Digest::SHA256.new)
show_digest_new(OpenSSL::Digest::SHA384.new)
show_digest_new(OpenSSL::Digest::SHA512.new)
class InitializedDigest < OpenSSL::Digest::SHA256
  def initialize
    super('initial')
    @tag = :constructor
  end
end
show_digest_new(InitializedDigest.new)
original = OpenSSL::Digest::SHA256.new('old')
def original.marker; :singleton; end
copy = original.new
p [copy.marker, copy.hexdigest, original.hexdigest]
snapshot = original.clone
snapshot.update('more')
p [snapshot.hexdigest, original.hexdigest]
class ResetAwareDigest < OpenSSL::Digest::SHA256
  def reset
    @reset_frozen = frozen? unless frozen?
    super
  end
end
original = ResetAwareDigest.new('old')
original.freeze
copy = original.new
p [copy.frozen?, copy.instance_variable_get(:@reset_frozen), copy.hexdigest]
original = OpenSSL::Digest::SHA256.new('old')
original.freeze
copy = original.new
p [copy.frozen?, copy.class.name, copy.hexdigest, original.hexdigest]
copy.update('abc')
p [copy.hexdigest, original.hexdigest]
[nil, 'abc', 1].each do |arg|
  begin
    original.new(arg)
  rescue => error
    p [error.class.name, error.message]
  end
end
