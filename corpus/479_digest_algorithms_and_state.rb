require 'digest/rmd160'
require 'digest/sha2'
{
  '' => '9c1185a5c5e9fc54612808977ee8f548b2258d31',
  'abc' => '8eb208f7e05d987a9b044a8e98c6b087f15a0bfc',
  'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq' => '12a053384a9c0c88e405a06c27dcf49ada62eb2b',
}.each do |message, expected|
  actual = Digest::RMD160.hexdigest(message)
  raise 'RIPEMD-160 vector mismatch' unless actual == expected
  p actual
end
p [55, 56, 63, 64, 65].map { |length| Digest::RMD160.hexdigest('a' * length) }
[256, 384, 512].each do |length|
  digest = Digest::SHA2.new(length) << 'abc'
  copy = digest.clone
  digest << 'def'
  p [length, copy.hexdigest, digest.new.digest_length, digest.hexdigest]
end
[Digest::MD5, Digest::SHA1, Digest::SHA256, Digest::SHA384, Digest::SHA512, Digest::RMD160].each do |klass|
  p [klass, klass.base64digest('abc').encoding]
end
begin; Digest::Base.allocate; rescue NotImplementedError => error; p error.class; end
begin; Digest::Base.new; rescue NotImplementedError => error; p error.class; end
begin
  Digest::MD5.allocate.send(:initialize_copy, Digest::RMD160.allocate)
rescue TypeError => error
  p error.class
end

class IncompleteDigest < Digest::Base; end
[:allocate, :new].each do |method|
  begin
    IncompleteDigest.send(method)
  rescue RuntimeError => error
    p [error.class, error.message]
  end
end
