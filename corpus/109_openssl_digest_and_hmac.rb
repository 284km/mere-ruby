# The half of openssl that is a hash function: mere-ruby already ships the
# digests, and HMAC is two hashes and an xor. The values below were compared
# against the real OpenSSL, not just against each other.
require "openssl"

p OpenSSL::Digest::SHA256.hexdigest("abc")
p OpenSSL::Digest::SHA1.hexdigest("abc")
p OpenSSL::Digest::MD5.hexdigest("abc")
p OpenSSL::Digest.new("SHA256").class.to_s
p OpenSSL::Digest::SHA256.new.class.to_s
p OpenSSL::Digest::SHA256.new.is_a?(OpenSSL::Digest)
p OpenSSL::Digest.new("SHA256").name
p OpenSSL::Digest.hexdigest("SHA256", "abc")

p OpenSSL::HMAC.hexdigest("SHA256", "key", "The quick brown fox jumps over the lazy dog")
p OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, "key", "data")
p OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("SHA1"), "key", "data")
p OpenSSL::HMAC.hexdigest("MD5", "key", "data")
p OpenSSL::HMAC.digest("SHA256", "k", "v").bytesize

# a key longer than the block size is hashed first
p OpenSSL::HMAC.hexdigest("SHA256", "x" * 100, "data")
# ...and a short one is zero-padded
p OpenSSL::HMAC.hexdigest("SHA256", "", "data")

h = OpenSSL::HMAC.new("key", OpenSSL::Digest::SHA256.new)
h << "da"
h.update("ta")
p h.hexdigest
p h.digest.bytesize

# HMAC refuses a Class, as ruby's does: it wants an instance or a name.
begin
  OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256, "key", "data")
rescue TypeError => e
  p [e.class, e.message]
end

# The error class of what mere-ruby cannot do is still a class (activesupport
# names OpenSSL::Cipher::CipherError at load time); using a cipher raises
# NotImplementedError, which is not compared here because ruby's works.
p OpenSSL::Cipher::CipherError.ancestors.include?(StandardError)

# Process.pid is the real one (libc), and $$ agrees with it
p Process.pid.class
p Process.pid > 0
p $$ == Process.pid

# A `rescue` modifier binds tighter than the `if` it sits in, so the condition
# is `(x = expr) rescue fallback`.
def risky(x)
  raise "boom" if x.odd?
  x * 10
end
p([1, 2, 3].map do |i|
  if v = risky(i) rescue nil
    v
  else
    :fallback
  end
end)
