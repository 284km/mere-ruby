require 'digest'
p [Object.private_method_defined?(:Digest), Kernel.private_method_defined?(:Digest)]
p [Digest(:SHA256) == Digest::SHA256, Digest('SHA512') == Digest::SHA512]
begin
  Digest(:MissingImplementation)
rescue LoadError => error
  p error.class
end
class Digest::Custom < Digest::Class
  def initialize; @buffer = []; end
  def initialize_copy(other); @buffer = other.instance_variable_get(:@buffer).dup; end
  def update(string); @buffer << string; self; end
  alias << update
  def reset; @buffer.clear; self; end
  def finish; [@buffer.join.bytesize % 256].pack('C'); end
end
p Digest(:Custom) == Digest::Custom
p [Digest::Base.superclass, Digest::Class.ancestors.include?(Digest::Instance)]
digest = Digest::Custom.new << 'abc'
p [digest.hexdigest, digest.hexdigest('xy'), digest.hexdigest, digest.digest_length]
digest << 'abcd'
copy = digest.new
p [copy.hexdigest, digest.hexdigest, digest.hexdigest!, digest.hexdigest]
p Digest::Custom.hexdigest('hello')
module IncludedResult; end
class IncludeReceiver; end
p IncludeReceiver.class_eval { include IncludedResult }
p IncludeReceiver.class_eval { prepend Enumerable }

# Digest comparison coerces text rather than delegating String#== back to it.
class ComparisonDigest < Digest::Class
  def finish; 'x'.b; end
end
class DigestText
  def to_str; '78'; end
end
class ReversedDigestEquality
  def to_str; 'different'; end
  def ==(_); true; end
end
class MissingDigestConversion; end
class NilDigestConversion
  def to_str; nil; end
end
class InvalidDigestConversion
  def to_str; 123; end
end
comparison = ComparisonDigest.new
p [comparison == DigestText.new, comparison == ReversedDigestEquality.new]
p [comparison == MissingDigestConversion.new, comparison == NilDigestConversion.new]
begin
  comparison == InvalidDigestConversion.new
rescue TypeError => error
  p error.class
end
p [comparison == ComparisonDigest.new, comparison == '78', comparison == 'different']
