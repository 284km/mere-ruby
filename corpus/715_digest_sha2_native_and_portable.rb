require "digest"
require "openssl"
require "tmpdir"

algorithms = [Digest::SHA256, Digest::SHA384, Digest::SHA512]
vectors = ["", "abc", "\0\x80\xff".b]
[55, 56, 63, 64, 65, 111, 112, 127, 128, 129].each { |n| vectors << "a" * n }
algorithms.each do |algorithm|
  puts algorithm.name
  p vectors.map { |data| algorithm.hexdigest(data) }
end

data = ("bytes\0\xff".b * 2500)
Dir.mktmpdir("digest-backend") do |dir|
  path = File.join(dir, "input.bin")
  File.binwrite(path, data)
  algorithms.each do |algorithm|
    digest = algorithm.new.update(data[0, 37])
    copy = digest.clone
    digest.update(data[37..])
    copy.update("different")
    GC.start
    p [algorithm.file(path).hexdigest, digest.hexdigest, copy.hexdigest]
    p [digest.digest(data).unpack1("H*"), digest.hexdigest]
  end
end
p [256, 384, 512].map { |bits| Digest::SHA2.new(bits).update("abc").hexdigest }
p [Digest::MD5.hexdigest("abc"), Digest::SHA1.hexdigest("abc")]

old_separator = $,
begin
  $, = "separator"
  p algorithms.map { |algorithm| algorithm.hexdigest("abc") }
ensure
  $, = old_separator
end
old_verbose = $VERBOSE
begin
  $VERBOSE = nil
  ractors = algorithms.map do |algorithm|
    Ractor.new(algorithm) { |klass| klass.hexdigest("abc") }
  end
  p ractors.map(&:value)
ensure
  $VERBOSE = old_verbose
end
p algorithms.map { |algorithm| algorithm.respond_to?(:__portable_digest) }

# The native provider is an implementation detail, not a Ruby callback.
require "openssl"
OpenSSL::Digest.define_singleton_method(:digest) { |*| raise "public digest callback" }
OpenSSL::Digest.define_singleton_method(:digests) { raise "public digest list callback" }
p algorithms.map { |algorithm| algorithm.hexdigest("abc") }
