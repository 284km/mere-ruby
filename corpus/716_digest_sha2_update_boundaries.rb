require "digest"
require "openssl"

# Binary data crossing an internal native update retains its final bytes.
data = "\0\x80\xff".b * 349526
[Digest::SHA256, Digest::SHA384, Digest::SHA512].each do |algorithm|
  p [algorithm.name, data.bytesize, algorithm.hexdigest(data)]
end
